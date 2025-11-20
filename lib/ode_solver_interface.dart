import 'dart:async';
import 'dart:math'; // 引入 math 以使用 pow, max, abs
import 'package:math_expressions/math_expressions.dart' as me;
import 'custom_vector.dart';

// --- 1. 向量函數評估 ---
List<double> evaluateVectorFunction(String expression, double t, List<double> y) {
  try {
    List<String> expressionsList = expression.split(',').map((e) => e.trim()).toList();
    
    if (expressionsList.length != y.length) {
      throw Exception("方程數量 (${expressionsList.length}) 與向量維度 (${y.length}) 不符。");
    }

    me.GrammarParser p = me.GrammarParser(); 
    me.ContextModel cm = me.ContextModel();
    
    cm.bindVariableName('t', me.Number(t));
    
    // 變數綁定: y(0)->y, y(1)->y1, y(2)->y2...
    for(int i = 0; i < y.length; i++) {
        if (i == 0) {
           cm.bindVariableName('y', me.Number(y[i])); 
        } else {
           cm.bindVariableName('y$i', me.Number(y[i]));
        }
    }
    
    List<double> derivatives = [];
    for (String expr in expressionsList) {
      if (expr.isEmpty) {
         derivatives.add(0.0);
         continue;
      }
      me.Expression exp = p.parse(expr);
      double result = exp.evaluate(me.EvaluationType.REAL, cm);
      
      if (result.isNaN || result.isInfinite) {
        throw Exception('計算發散: $expr');
      }
      derivatives.add(result);
    }
    return derivatives;

  } catch (e) {
    throw Exception('表達式運算錯誤: $e');
  }
}

// --- 2. 求解器方法 Enum ---
enum ODEMethod {
  euler,
  rungeKutta4,
  adaptiveRk45, // 新增：自適應 RK45
}

extension ODEMethodExtension on ODEMethod {
  String get name {
    switch (this) {
      case ODEMethod.euler:
        return '歐拉法 (Euler)';
      case ODEMethod.rungeKutta4:
        return '四階龍格-庫塔 (RK4)';
      case ODEMethod.adaptiveRk45:
        return '自適應 RK45 (RKF45)';
    }
  }
}

// --- 3. 核心求解函式 ---
Future<List<List<double>>> solveODE({
  required String expression,
  required double t0,
  required List<double> y0,
  required double tEnd,
  required int nSteps, // 若是 RK45，此參數作為最大迭代次數上限
  required ODEMethod method,
  double tolerance = 1e-6, // RK45 專用容許誤差
}) async {
  
  if (tEnd <= t0) {
    throw Exception("結束時間 tEnd 必須大於起始時間 t0");
  }

  double t = t0;
  CustomVector y = CustomVector.fromList(y0); 
  List<List<double>> results = [];

  // 初始步長 (對於 Euler/RK4 是固定的，對於 RK45 是初始猜測)
  double h = (tEnd - t0) / nSteps;

  switch (method) {
    // === 歐拉法 (Euler) ===
    case ODEMethod.euler:
      for (int i = 0; i <= nSteps; i++) {
        results.add([t, ...y.values]);
        if (i == nSteps) break; 
        List<double> dydtList = evaluateVectorFunction(expression, t, y.values); 
        y = y + CustomVector.fromList(dydtList).scale(h);
        t = t + h;
      }
      break;

    // === 四階龍格-庫塔法 (RK4) ===
    case ODEMethod.rungeKutta4:
      for (int i = 0; i <= nSteps; i++) {
        results.add([t, ...y.values]);
        if (i == nSteps) break; 

        List<double> k1L = evaluateVectorFunction(expression, t, y.values);
        CustomVector k1 = CustomVector.fromList(k1L);

        List<double> k2L = evaluateVectorFunction(expression, t + h/2, (y + k1.scale(h/2)).values);
        CustomVector k2 = CustomVector.fromList(k2L);

        List<double> k3L = evaluateVectorFunction(expression, t + h/2, (y + k2.scale(h/2)).values);
        CustomVector k3 = CustomVector.fromList(k3L);

        List<double> k4L = evaluateVectorFunction(expression, t + h, (y + k3.scale(h)).values);
        CustomVector k4 = CustomVector.fromList(k4L);

        y = y + (k1 + k2.scale(2) + k3.scale(2) + k4).scale(h / 6);
        t = t + h;
      }
      break;

    // === 自適應 RK45 (Runge-Kutta-Fehlberg) ===
    case ODEMethod.adaptiveRk45:
      // Cash-Karp 参数表
      const c2 = 1.0/4.0, c3 = 3.0/8.0, c4 = 12.0/13.0, c5 = 1.0, c6 = 1.0/2.0;
      const a21 = 1.0/4.0;
      const a31 = 3.0/32.0, a32 = 9.0/32.0;
      const a41 = 1932.0/2197.0, a42 = -7200.0/2197.0, a43 = 7296.0/2197.0;
      const a51 = 439.0/216.0, a52 = -8.0, a53 = 3680.0/513.0, a54 = -845.0/4104.0;
      const a61 = -8.0/27.0, a62 = 2.0, a63 = -3544.0/2565.0, a64 = 1859.0/4104.0, a65 = -11.0/40.0;
      
      // 5階解權重
      const b1 = 16.0/135.0, b3 = 6656.0/12825.0, b4 = 28561.0/56430.0, b5 = -9.0/50.0, b6 = 2.0/55.0;
      // 誤差估計權重 (E = 4階 - 5階)
      const e1 = 1.0/360.0, e3 = -128.0/4275.0, e4 = -2197.0/75240.0, e5 = 1.0/50.0, e6 = 2.0/55.0;

      int steps = 0;
      int maxSafeSteps = 200000; // 防止無窮迴圈
      
      results.add([t, ...y.values]);

      while (t < tEnd && steps < maxSafeSteps) {
        if (t + h > tEnd) h = tEnd - t;

        // 計算 6 個斜率
        CustomVector k1 = CustomVector.fromList(evaluateVectorFunction(expression, t, y.values));
        CustomVector k2 = CustomVector.fromList(evaluateVectorFunction(expression, t + c2*h, (y + k1.scale(h*a21)).values));
        CustomVector k3 = CustomVector.fromList(evaluateVectorFunction(expression, t + c3*h, (y + k1.scale(h*a31) + k2.scale(h*a32)).values));
        CustomVector k4 = CustomVector.fromList(evaluateVectorFunction(expression, t + c4*h, (y + k1.scale(h*a41) + k2.scale(h*a42) + k3.scale(h*a43)).values));
        CustomVector k5 = CustomVector.fromList(evaluateVectorFunction(expression, t + c5*h, (y + k1.scale(h*a51) + k2.scale(h*a52) + k3.scale(h*a53) + k4.scale(h*a54)).values));
        CustomVector k6 = CustomVector.fromList(evaluateVectorFunction(expression, t + c6*h, (y + k1.scale(h*a61) + k2.scale(h*a62) + k3.scale(h*a63) + k4.scale(h*a64) + k5.scale(h*a65)).values));

        // 計算誤差
        CustomVector errorVec = (k1.scale(e1) + k3.scale(e3) + k4.scale(e4) + k5.scale(e5) + k6.scale(e6)).scale(h);
        double maxError = 0.0;
        for(double val in errorVec.values) maxError = max(maxError, val.abs());
        if (maxError == 0.0) maxError = 1e-16;

        // 檢查是否接受這一步
        if (maxError <= tolerance) {
          t = t + h;
          y = y + (k1.scale(b1) + k3.scale(b3) + k4.scale(b4) + k5.scale(b5) + k6.scale(b6)).scale(h);
          results.add([t, ...y.values]);
          steps++;
        }

        // 調整步長 h (自適應核心)
        double delta = 0.84 * pow((tolerance / maxError), 0.25);
        if (delta > 4.0) delta = 4.0;
        if (delta < 0.1) delta = 0.1;
        h = h * delta;

        // 步長限制
        if (h > (tEnd - t0) / 5.0) h = (tEnd - t0) / 5.0;
        if (h < 1e-10) h = 1e-10;
      }
      break;
  }
  
  return results;
}