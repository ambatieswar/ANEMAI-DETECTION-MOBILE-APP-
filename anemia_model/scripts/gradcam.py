"""Generate genuine Grad-CAM heatmaps for a trained Keras screening model."""

from __future__ import annotations

import argparse
from pathlib import Path

import tensorflow as tf
import numpy as np
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--layer", default="mobile_net_v3_small")
    args = parser.parse_args()

    model = tf.keras.models.load_model(args.model)
    layer = model.get_layer(args.layer)
    grad_model = tf.keras.Model(model.inputs, [layer.output, model.output])
    image = Image.open(args.image).convert("RGB").resize((224, 224))
    array = np.asarray(image, dtype=np.float32)[None, ...]
    array = tf.keras.applications.mobilenet_v3.preprocess_input(array)

    with tf.GradientTape() as tape:
        activations, prediction = grad_model(array)
        target = prediction[:, 0]
    gradients = tape.gradient(target, activations)
    weights = tf.reduce_mean(gradients, axis=(1, 2), keepdims=True)
    heatmap = tf.reduce_sum(weights * activations, axis=-1)[0]
    heatmap = tf.maximum(heatmap, 0)
    heatmap /= tf.maximum(tf.reduce_max(heatmap), 1e-8)
    heatmap = tf.image.resize(heatmap[..., None], (224, 224))[..., 0]
    heatmap = tf.cast(heatmap * 255, tf.uint8).numpy()
    Image.fromarray(heatmap, mode="L").save(args.output)


if __name__ == "__main__":
    main()
