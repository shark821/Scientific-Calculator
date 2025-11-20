// lib/custom_vector.dart

/// 專門用於 ODE 求解的向量類別，實作運算子重載。
class CustomVector {
  final List<double> values;

  CustomVector(this.values) {
    if (values.isEmpty) {
      throw Exception("CustomVector 不能為空。");
    }
  }

  int get length => values.length;

  /// 將 List<double> 轉換為 CustomVector
  static CustomVector fromList(List<double> list) {
    return CustomVector(list);
  }

  /// 向量加法 (Vector + Vector)
  CustomVector operator +(CustomVector other) {
    if (length != other.length) {
      throw Exception("向量加法要求維度相同: $length != ${other.length}");
    }
    List<double> result = [];
    for (int i = 0; i < length; i++) {
      result.add(values[i] + other.values[i]);
    }
    return CustomVector(result);
  }

  /// 標量乘法 (Vector * Scalar)
  CustomVector operator *(double scalar) {
    List<double> result = [];
    for (int i = 0; i < length; i++) {
      result.add(values[i] * scalar);
    }
    return CustomVector(result);
  }
  
  /// 標量乘法 (Scalar * Vector) - 讓順序顛倒也能工作
  CustomVector scale(double scalar) {
    return this * scalar;
  }

  @override
  String toString() {
    return values.map((e) => e.toStringAsFixed(4)).join(', ');
  }
}