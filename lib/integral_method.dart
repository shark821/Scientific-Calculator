import 'package:math_expressions/math_expressions.dart';

// --- 1. 積分方法 Enum ---
enum IntegrationMethod {
  trapezoidal,
  simpson,
  adaptiveSimpson, // 修正：已為 lowerCamelCase
}

// 積分方法的名稱和說明 (用於 UI 顯示)
extension IntegrationMethodExtension on IntegrationMethod {
  String get name {
    switch (this) {
      case IntegrationMethod.trapezoidal:
        return '梯形法則 (Trapezoidal Rule)';
      case IntegrationMethod.simpson:
        return '辛普森法則 (Simpson\'s Rule)';
      case IntegrationMethod.adaptiveSimpson:
        return '自適應辛普森法則(Adaptive Simpson\'s Method)';
    }
  }
}

// --- 2. 核心計算函數 ---

/// 評估給定函數在特定 x 值上的結果
double evaluateFunction(String expression, double x) {
  try {
    Parser p = Parser();
    Expression exp = p.parse(expression);

    ContextModel cm = ContextModel()
      ..bindVariableName('x', Number(x));
    
    double result = exp.evaluate(EvaluationType.REAL, cm);

    if (result.isNaN || result.isInfinite) {
      throw FormatException('在 x=$x 處，函數計算出無效值 (如除以零)。');
    }
    
    return result;

  } catch (e) {
    throw FormatException('無效的函數表達式或計算錯誤: $e');
  }
}


/// 執行數值積分
double numericalIntegrate({
  required String expression,
  required double a,
  required double b,
  required int n,
  required IntegrationMethod method,
  double epsilon = 1e-6, 
}) {
  if (n <= 0 && method != IntegrationMethod.adaptiveSimpson) throw Exception("區間數 N 必須大於 0");
  if (method == IntegrationMethod.simpson && n % 2 != 0) {
    throw Exception("辛普森法則要求區間數 N 必須為偶數");
  }

  // 評估 f(x) 的輔助函數
  double f(double x) => evaluateFunction(expression, x);

  // -------------------------------------------------------------
  if (method == IntegrationMethod.trapezoidal) {
    final double h = (b - a) / n;
    double sum = f(a) + f(b);
    for (int i = 1; i < n; i++) {
      final double xi = a + i * h; 
      sum += 2 * f(xi);
    }
    return sum * (h / 2);

  } else if (method == IntegrationMethod.simpson) {
    final double h = (b - a) / n;
    double sum = f(a) + f(b);
    
    for (int i = 1; i < n; i++) {
      final double xi = a + i * h;
      final double fx = f(xi);
      sum += (i % 2 == 1) ? 4 * fx : 2 * fx;
    }
    return sum * (h / 3);

  } else if (method == IntegrationMethod.adaptiveSimpson) {
    // --- 自適應辛普森法則 ---
    
    double adaptiveSimpson(double a, double b, double eps, double whole) {
      final double c = (a + b) / 2.0;
      final double halfH = (c - a) / 6.0;
      
      final double iLeft = halfH * (f(a) + 4 * f((a + c) / 2.0) + f(c));
      final double iRight = halfH * (f(c) + 4 * f((c + b) / 2.0) + f(b));
      
      final double iNew = iLeft + iRight;

      if ((iNew - whole).abs() <= 15.0 * eps) {
        return iNew + (iNew - whole) / 15.0;
      }
      
      return adaptiveSimpson(a, c, eps / 2.0, iLeft) +
             adaptiveSimpson(c, b, eps / 2.0, iRight);
    }
    
    final double initialWhole = (b - a) / 6.0 * (f(a) + 4 * f((a + b) / 2.0) + f(b));
    
    return adaptiveSimpson(a, b, epsilon, initialWhole);
    
  }
  
  return 0.0;
}