class AttentionModelConfig {
  static const int sequenceLength = 15;
  static const List<int> landmarkIndices = [
    33,
    133,
    160,
    144,
    362,
    263,
    385,
    380,
    1,
    4,
    61,
    291,
  ];

  static const int landmarkNodeCount = 12;
  static const int coordinateCount = 3;
  static const int temporalFeatureCount = 44;

  static const String cnnLstmAsset = 'assets/models/focusmate_cnn_lstm.tflite';
  static const String gnnAsset = 'assets/models/focusmate_gnn.tflite';
}
