from __future__ import annotations

import argparse
import os
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
import pandas as pd
from mediapipe.tasks.python import BaseOptions
from mediapipe.tasks.python.vision import FaceLandmarker
from mediapipe.tasks.python.vision import FaceLandmarkerOptions

LANDMARK_INDICES = [33, 133, 160, 144, 362, 263, 385, 380, 1, 4, 61, 291]
CLASS_LABELS = {
    "Engaged": 0,
    "Not_Engaged": 1,
}


def build_landmarker(model_path: str) -> FaceLandmarker:
    options = FaceLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=model_path),
        output_face_blendshapes=False,
        output_facial_transformation_matrixes=False,
        num_faces=1,
    )
    return FaceLandmarker.create_from_options(options)


def calculate_ear(landmarks) -> float:
    def eye_ear(indices: list[int]) -> float:
        p1, p2, p3, p4, p5, p6 = [landmarks[index] for index in indices]
        v1 = np.linalg.norm([p2.x - p6.x, p2.y - p6.y, p2.z - p6.z])
        v2 = np.linalg.norm([p3.x - p5.x, p3.y - p5.y, p3.z - p5.z])
        h = np.linalg.norm([p1.x - p4.x, p1.y - p4.y, p1.z - p4.z])
        return 0.0 if h == 0 else (v1 + v2) / (2.0 * h)

    return (eye_ear([33, 160, 158, 133, 153, 144]) + eye_ear([362, 385, 387, 263, 373, 380])) / 2.0


def calculate_head_pose(landmarks) -> tuple[float, float, float]:
    nose_tip = landmarks[4]
    chin = landmarks[152]
    left_eye = landmarks[33]
    right_eye = landmarks[263]

    pitch_den = max(chin.y - nose_tip.y, 1e-6)
    yaw_den = max(right_eye.x - left_eye.x, 1e-6)

    pitch = (nose_tip.y - (left_eye.y + right_eye.y) / 2) / pitch_den
    yaw = (nose_tip.x - (left_eye.x + right_eye.x) / 2) / yaw_den
    roll = (right_eye.y - left_eye.y) / yaw_den
    return float(pitch), float(yaw), float(roll)


def calculate_mouth_aspect_ratio(landmarks) -> float:
    upper = landmarks[13]
    lower = landmarks[14]
    left = landmarks[61]
    right = landmarks[291]
    width = np.linalg.norm([left.x - right.x, left.y - right.y, left.z - right.z])
    if width == 0:
        return 0.0
    return float(np.linalg.norm([upper.x - lower.x, upper.y - lower.y, upper.z - lower.z]) / width)


def calculate_brow_distance(landmarks) -> float:
    left = np.linalg.norm(
        [
            landmarks[70].x - landmarks[159].x,
            landmarks[70].y - landmarks[159].y,
            landmarks[70].z - landmarks[159].z,
        ]
    )
    right = np.linalg.norm(
        [
            landmarks[300].x - landmarks[386].x,
            landmarks[300].y - landmarks[386].y,
            landmarks[300].z - landmarks[386].z,
        ]
    )
    return float((left + right) / 2.0)


def calculate_iris_distance(landmarks) -> float:
    nose = landmarks[1]
    nose_tip = landmarks[4]
    left_eye = landmarks[33]
    right_eye = landmarks[263]
    eye_span = np.linalg.norm([left_eye.x - right_eye.x, left_eye.y - right_eye.y, left_eye.z - right_eye.z])
    if eye_span == 0:
        return 0.0
    return float(np.linalg.norm([nose.x - nose_tip.x, nose.y - nose_tip.y, nose.z - nose_tip.z]) / eye_span)


def extract_normalized_landmarks(landmarks) -> list[float]:
    nose = landmarks[1]
    left_eye = landmarks[33]
    right_eye = landmarks[263]
    scale = max(np.linalg.norm([left_eye.x - right_eye.x, left_eye.y - right_eye.y, left_eye.z - right_eye.z]), 1e-6)

    values: list[float] = []
    for index in LANDMARK_INDICES:
        point = landmarks[index]
        values.extend(
            [
                float((point.x - nose.x) / scale),
                float((point.y - nose.y) / scale),
                float((point.z - nose.z) / scale),
            ]
        )
    return values


def extract_features(dataset_dir: Path, model_path: Path, output_csv: Path) -> pd.DataFrame:
    detector = build_landmarker(str(model_path))
    rows: list[dict[str, object]] = []

    for class_name, attention_label in CLASS_LABELS.items():
      class_dir = dataset_dir / class_name
      if not class_dir.exists():
          continue

      for sub_dir in sorted(path for path in class_dir.iterdir() if path.is_dir()):
          sequence_id = f"{class_name}/{sub_dir.name}"
          for frame_index, image_path in enumerate(sorted(sub_dir.iterdir())):
              if image_path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                  continue

              image = cv2.imread(str(image_path))
              if image is None:
                  continue

              image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
              mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image_rgb)
              result = detector.detect(mp_image)
              if not result.face_landmarks:
                  continue

              landmarks = result.face_landmarks[0]
              ear = calculate_ear(landmarks)
              pitch, yaw, roll = calculate_head_pose(landmarks)
              mouth_aspect_ratio = calculate_mouth_aspect_ratio(landmarks)
              brow_distance = calculate_brow_distance(landmarks)
              iris_distance = calculate_iris_distance(landmarks)
              face_width = max(abs(landmarks[33].x - landmarks[263].x), 1e-6)
              face_height = max(abs(landmarks[152].y - landmarks[10].y), 1e-6)
              landmark_values = extract_normalized_landmarks(landmarks)

              row: dict[str, object] = {
                  "sequence_id": sequence_id,
                  "class_name": class_name,
                  "frame_name": image_path.name,
                  "frame_index": frame_index,
                  "attention_label": attention_label,
                  "ear": ear,
                  "yaw": yaw,
                  "pitch": pitch,
                  "roll": roll,
                  "mouth_aspect_ratio": mouth_aspect_ratio,
                  "brow_distance": brow_distance,
                  "iris_distance": iris_distance,
                  "face_aspect_ratio": float(face_height / face_width),
              }

              for node_index in range(len(LANDMARK_INDICES)):
                  base = node_index * 3
                  row[f"node_{node_index}_x"] = landmark_values[base]
                  row[f"node_{node_index}_y"] = landmark_values[base + 1]
                  row[f"node_{node_index}_z"] = landmark_values[base + 2]

              rows.append(row)

    detector.close()
    df = pd.DataFrame(rows).sort_values(["sequence_id", "frame_index"]).reset_index(drop=True)
    output_csv.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_csv, index=False)
    return df


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract landmark-based attention features.")
    parser.add_argument("--dataset", default="dataset", help="Dataset directory.")
    parser.add_argument("--model", default="face_landmarker.task", help="MediaPipe face landmarker task file.")
    parser.add_argument("--output", default="features_landmarks.csv", help="Output CSV path.")
    args = parser.parse_args()

    df = extract_features(Path(args.dataset), Path(args.model), Path(args.output))
    print(f"Saved {len(df)} labeled frames to {args.output}")


if __name__ == "__main__":
    main()
