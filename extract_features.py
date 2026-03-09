import cv2
import mediapipe as mp
from mediapipe.tasks.python import BaseOptions
from mediapipe.tasks.python.vision import FaceLandmarker, FaceLandmarkerOptions
import os
import pandas as pd
import numpy as np

# Initialize MediaPipe Tasks API
base_options = BaseOptions(model_asset_path='face_landmarker.task')
options = FaceLandmarkerOptions(base_options=base_options,
                                 output_face_blendshapes=True,
                                 output_facial_transformation_matrixes=True,
                                 num_faces=1)
detector = FaceLandmarker.create_from_options(options)

def calculate_ear(landmarks):
    def get_eye_ear(eye_points):
        v1 = np.linalg.norm(np.array([landmarks[eye_points[1]].x, landmarks[eye_points[1]].y, landmarks[eye_points[1]].z]) - np.array([landmarks[eye_points[5]].x, landmarks[eye_points[5]].y, landmarks[eye_points[5]].z]))
        v2 = np.linalg.norm(np.array([landmarks[eye_points[2]].x, landmarks[eye_points[2]].y, landmarks[eye_points[2]].z]) - np.array([landmarks[eye_points[4]].x, landmarks[eye_points[4]].y, landmarks[eye_points[4]].z]))
        h = np.linalg.norm(np.array([landmarks[eye_points[0]].x, landmarks[eye_points[0]].y, landmarks[eye_points[0]].z]) - np.array([landmarks[eye_points[3]].x, landmarks[eye_points[3]].y, landmarks[eye_points[3]].z]))
        return (v1 + v2) / (2.0 * h)
    left_ear = get_eye_ear([33, 160, 158, 133, 153, 144])
    right_ear = get_eye_ear([362, 385, 387, 263, 373, 380])
    return (left_ear + right_ear) / 2.0

def get_head_pose(landmarks, img_w, img_h):
    indices = [1, 33, 263, 61, 291, 199]
    image_points = np.array([[landmarks[i].x * img_w, landmarks[i].y * img_h] for i in indices], dtype="double")
    model_points = np.array([(0.0, 0.0, 0.0), (-225.0, 170.0, -135.0), (225.0, 170.0, -135.0), (-150.0, -150.0, -125.0), (150.0, -150.0, -125.0), (0.0, -330.0, -65.0)])
    focal_length = img_w
    center = (img_w / 2, img_h / 2)
    camera_matrix = np.array([[focal_length, 0, center[0]], [0, focal_length, center[1]], [0, 0, 1]], dtype="double")
    dist_coeffs = np.zeros((4, 1))
    success, rotation_vector, translation_vector = cv2.solvePnP(model_points, image_points, camera_matrix, dist_coeffs, flags=cv2.SOLVEPNP_ITERATIVE)
    # Convert rotation vector to euler angles
    rmat, _ = cv2.Rodrigues(rotation_vector)
    # decomposeProjectionMatrix returns 7 values
    ret = cv2.decomposeProjectionMatrix(np.hstack((rmat, translation_vector)))
    eulerAngles = ret[6]
    pitch, yaw, roll = eulerAngles.flatten()
    return pitch, yaw, roll

def extract_features_from_dataset(base_path):
    data = []
    classes = {'Engaged': 1, 'Not_Engaged': 0}
    for class_name, label in classes.items():
        class_path = os.path.join(base_path, class_name)
        if not os.path.exists(class_path): continue
        for sub_folder in os.listdir(class_path):
            sub_path = os.path.join(class_path, sub_folder)
            if not os.path.isdir(sub_path): continue
            print(f"Processing {class_name}/{sub_folder}...")
            
            # Sort images to maintain temporal order for sequences
            images = sorted(os.listdir(sub_path))
            
            for img_name in images:
                img_path = os.path.join(sub_path, img_name)
                image = cv2.imread(img_path)
                if image is None: continue
                h, w, _ = image.shape
                mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
                result = detector.detect(mp_image)
                
                if result.face_landmarks:
                    face_landmarks = result.face_landmarks[0]
                    # Extract 468 landmarks as flattened X,Y,Z vectors
                    landmarks_vector = []
                    for lm in face_landmarks:
                        landmarks_vector.extend([lm.x, lm.y, lm.z])
                    
                    ear = calculate_ear(face_landmarks)
                    pitch, yaw, roll = get_head_pose(face_landmarks, w, h)
                    
                    row = {
                        'ear': ear, 
                        'pitch': pitch, 
                        'yaw': yaw, 
                        'roll': roll, 
                        'label': label,
                        'sub_folder': sub_folder # identify sequence
                    }
                    # Add raw landmarks for GNN/Transformer
                    for i, val in enumerate(landmarks_vector):
                        row[f'lm_{i}'] = val
                        
                    data.append(row)
                    
    df = pd.DataFrame(data)
    df.to_csv('features_landmarks.csv', index=False)
    print(f"Features saved to features_landmarks.csv. Total samples: {len(df)}")

if __name__ == "__main__":
    dataset_base = r'C:\Users\KamalHp\Downloads\focusmateapp\dataset'
    extract_features_from_dataset(dataset_base)
