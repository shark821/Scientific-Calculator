import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:ml_linalg/linalg.dart' as linalg; 
import 'integral_method.dart'; 
import 'ode_solver_interface.dart'; 
import 'custom_vector.dart';
import 'package:math_expressions/math_expressions.dart' as me;

void main() {
  runApp(const EngineeringCalculatorApp());
}

class EngineeringCalculatorApp extends StatelessWidget {
  const EngineeringCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Numeric - 科學計算機',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(), 
    );
  }
}

// --- 輔助 UI ---
Widget _buildInputCard({
  required String title, 
  required TextEditingController controller, 
  required String hint,
  required TextInputType keyboardType,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: 1,
        decoration: InputDecoration(
          hintText: hint, 
          border: const OutlineInputBorder(), 
          contentPadding: const EdgeInsets.all(10)
        ),
      ),
    ],
  );
}

// --- 主頁面 ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Numeric - Home'),
        centerTitle: true,
      ),
      body: Center( 
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900), 
          padding: const EdgeInsets.all(24),
          child: GridView.count(
            crossAxisCount: 2, 
            mainAxisSpacing: 24, 
            crossAxisSpacing: 24, 
            childAspectRatio: 1.5, 
            shrinkWrap: true, 
            children: [
              _buildFeatureCard(context, Icons.grid_on, '矩陣運算', 0),
              _buildFeatureCard(context, Icons.linear_scale, '解方程', 1),
              _buildFeatureCard(context, Icons.calculate, '數值微積分', 2),
              _buildFeatureCard(context, Icons.analytics, 'ODE 求解器', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, IconData icon, String title, int index) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FunctionalShell(initialIndex: index),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: Colors.indigo.shade700),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// --- 導航殼層 ---
class FunctionalShell extends StatefulWidget {
  final int initialIndex;
  const FunctionalShell({super.key, required this.initialIndex});

  @override
  State<FunctionalShell> createState() => _FunctionalShellState();
}

class _FunctionalShellState extends State<FunctionalShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  static final List<Widget> _pages = <Widget>[
    const MatrixPage(),      
    const SolverPage(),      
    const CalculusPage(),    
    const OdePage(),         
  ];

  static const List<String> _pageTitles = [
    '矩陣運算 (Matrix)',
    '解方程 (Solvers)',
    '數值微積分 (Calculus)',
    '常微分方程 (ODE)',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitles[_selectedIndex])),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: '矩陣'),
          BottomNavigationBarItem(icon: Icon(Icons.linear_scale), label: '求解'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: '微積分'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'ODE'), 
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitles[_selectedIndex])),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(icon: Icon(Icons.grid_on), label: Text('矩陣')),
              NavigationRailDestination(icon: Icon(Icons.linear_scale), label: Text('求解')),
              NavigationRailDestination(icon: Icon(Icons.calculate), label: Text('微積分')),
              NavigationRailDestination(icon: Icon(Icons.analytics), label: Text('ODE')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

// --- 頁面 A: 矩陣運算 ---
class MatrixPage extends StatefulWidget {
  const MatrixPage({super.key});
  @override
  State<MatrixPage> createState() => _MatrixPageState();
}

class _MatrixPageState extends State<MatrixPage> {
  final TextEditingController _matrixAController = TextEditingController(text: '[[1.0, 2.0], [3.0, 4.0]]');
  final TextEditingController _matrixBController = TextEditingController(text: '[[5.0, 6.0], [7.0, 8.0]]');
  String _result = '尚未計算';
  bool _isLoading = false;

  Future<void> _calculateMatrixMultiply() async {
    setState(() { _isLoading = true; _result = '計算中...'; });
    try {
      final listA = jsonDecode(_matrixAController.text) as List;
      final listB = jsonDecode(_matrixBController.text) as List;
      final matrixA = linalg.Matrix.fromList(listA.map((row) => (row as List).map((e) => (e as num).toDouble()).toList()).toList());
      final matrixB = linalg.Matrix.fromList(listB.map((row) => (row as List).map((e) => (e as num).toDouble()).toList()).toList());
      final resultMatrix = matrixA * matrixB;
      setState(() { _result = resultMatrix.toString(); _isLoading = false; });
    } catch (e) {
      setState(() { _result = '錯誤: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildInputCard(title: '矩陣 A', controller: _matrixAController, hint: 'JSON', keyboardType: TextInputType.multiline),
          const SizedBox(height: 16),
          _buildInputCard(title: '矩陣 B', controller: _matrixBController, hint: 'JSON', keyboardType: TextInputType.multiline),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _calculateMatrixMultiply,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading ? const CircularProgressIndicator() : const Text('計算矩陣乘法', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 24),
          const Text('計算結果:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black12,
            child: SelectableText(_result, style: const TextStyle(fontSize: 18, fontFamily: 'Monospace')),
          ),
        ],
      ),
    );
  }
}

// --- 頁面 B: 解方程 ---
class SolverPage extends StatefulWidget {
  const SolverPage({super.key});
  @override
  State<SolverPage> createState() => _SolverPageState();
}

class _SolverPageState extends State<SolverPage> {
  final TextEditingController _matrixAController = TextEditingController(text: '[[1.0, 2.0], [3.0, 4.0]]');
  final TextEditingController _vectorBController = TextEditingController(text: '[5.0, 6.0]'); 
  String _result = '尚未計算解向量 x';
  bool _isLoading = false;

  Future<void> _solveLinearSystem() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _result = '計算中...'; });

    try {
      final List<List<double>> listA = (jsonDecode(_matrixAController.text) as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList()).toList();
      final List<double> listB = (jsonDecode(_vectorBController.text) as List)
          .map((e) => (e as num).toDouble()).toList();

      if (listA.length != listB.length) throw Exception("維度不符");
      final int N = listA.length;

      final List<List<double>> augmentedList = [];
      for (int i = 0; i < N; i++) augmentedList.add([...listA[i], listB[i]]);
      linalg.Matrix augmentedMatrix = linalg.Matrix.fromList(augmentedList);
      
      for (int i = 0; i < N; i++) {
        if (augmentedMatrix[i][i].abs() < 1e-9) throw Exception("奇異矩陣或主元為零");
        for (int j = i + 1; j < N; j++) {
          final double factor = augmentedMatrix[j][i] / augmentedMatrix[i][i];
          linalg.Vector newRowJ = augmentedMatrix[j] - (augmentedMatrix[i] * factor);
          List<linalg.Vector> newRows = augmentedMatrix.rows.toList();
          newRows[j] = newRowJ;
          augmentedMatrix = linalg.Matrix.fromRows(newRows); 
        }
      }
      
      final List<double> solution = List<double>.filled(N, 0.0);
      for (int i = N - 1; i >= 0; i--) {
        double sum = 0.0;
        for (int j = i + 1; j < N; j++) sum += augmentedMatrix[i][j] * solution[j];
        solution[i] = (augmentedMatrix[i][N] - sum) / augmentedMatrix[i][i];
      }

      String solutionStr = '解向量 x = [${solution.map((e) => e.toStringAsFixed(4)).join(', ')}]';
      setState(() { _isLoading = false; _result = solutionStr; });
    } catch (e) {
      setState(() { _isLoading = false; _result = '錯誤: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView( 
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('解多元一次方程 (Ax = b)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildInputCard(title: '矩陣 A', controller: _matrixAController, hint: 'JSON', keyboardType: TextInputType.multiline),
          const SizedBox(height: 12),
          _buildInputCard(title: '向量 b', controller: _vectorBController, hint: 'JSON', keyboardType: TextInputType.multiline),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _solveLinearSystem,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading ? const CircularProgressIndicator() : const Text('高斯消去法', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 30),
          const Text('解向量 x:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.indigo.shade200), borderRadius: BorderRadius.circular(8)),
            child: SelectableText(_result, style: const TextStyle(fontSize: 16, fontFamily: 'Monospace')),
          ),
        ],
      ),
    );
  }
}

// --- 頁面 C: 微積分 ---
class CalculusPage extends StatefulWidget {
  const CalculusPage({super.key});
  @override
  State<CalculusPage> createState() => _CalculusPageState();
}

class _CalculusPageState extends State<CalculusPage> {
  final TextEditingController _intFunctionController = TextEditingController(text: 'x^2'); 
  final TextEditingController _lowerLimitController = TextEditingController(text: '0.0'); 
  final TextEditingController _upperLimitController = TextEditingController(text: '1.0'); 
  final TextEditingController _intNController = TextEditingController(text: '1000'); 
  final TextEditingController _epsilonController = TextEditingController(text: '1e-6'); 
  IntegrationMethod _selectedIntMethod = IntegrationMethod.trapezoidal;
  String _intResult = '尚未計算';
  bool _isIntLoading = false;

  final TextEditingController _diffFunctionController = TextEditingController(text: 'x^2'); 
  final TextEditingController _diffPointController = TextEditingController(text: '2.0'); 
  final TextEditingController _diffStepController = TextEditingController(text: '0.0001'); 
  String _diffResult = '尚未計算';
  bool _isDiffLoading = false;

  Future<void> _calculateIntegral() async {
    if (_isIntLoading) return;
    setState(() => _isIntLoading = true);
    try {
      final String expression = _intFunctionController.text;
      final double a = double.parse(_lowerLimitController.text);
      final double b = double.parse(_upperLimitController.text);
      int n = 1000; double eps = 1e-6;
      if (_selectedIntMethod == IntegrationMethod.adaptiveSimpson) eps = double.parse(_epsilonController.text);
      else n = int.parse(_intNController.text);
      
      final double val = numericalIntegrate(expression: expression, a: a, b: b, n: n, method: _selectedIntMethod, epsilon: eps);
      setState(() { _intResult = val.toStringAsFixed(8); _isIntLoading = false; });
    } catch (e) { setState(() { _intResult = '錯誤: $e'; _isIntLoading = false; }); }
  }

  Future<void> _calculateDerivative() async {
    if (_isDiffLoading) return;
    setState(() => _isDiffLoading = true);
    try {
      final String expr = _diffFunctionController.text;
      final double x = double.parse(_diffPointController.text);
      final double h = double.parse(_diffStepController.text);
      me.GrammarParser p = me.GrammarParser();
      me.Expression exp = p.parse(expr);
      me.ContextModel cmPlus = me.ContextModel()..bindVariableName('x', me.Number(x + h));
      me.ContextModel cmMinus = me.ContextModel()..bindVariableName('x', me.Number(x - h));
      double fPlus = exp.evaluate(me.EvaluationType.REAL, cmPlus);
      double fMinus = exp.evaluate(me.EvaluationType.REAL, cmMinus);
      double res = (fPlus - fMinus) / (2 * h);
      setState(() { _diffResult = res.toStringAsFixed(8); _isDiffLoading = false; });
    } catch (e) { setState(() { _diffResult = '錯誤: $e'; _isDiffLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('數值積分 (Integration)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: 16),
          _buildInputCard(title: '函數 f(x)', controller: _intFunctionController, hint: 'x^2', keyboardType: TextInputType.text),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _buildInputCard(title: '下限 a', controller: _lowerLimitController, hint: '0', keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: _buildInputCard(title: '上限 b', controller: _upperLimitController, hint: '1', keyboardType: TextInputType.number))]),
          const SizedBox(height: 12),
          DropdownButton<IntegrationMethod>(value: _selectedIntMethod, isExpanded: true, items: IntegrationMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(), onChanged: (v) => setState(() => _selectedIntMethod = v!)),
          const SizedBox(height: 12),
          if (_selectedIntMethod == IntegrationMethod.adaptiveSimpson) _buildInputCard(title: '容許誤差 ε', controller: _epsilonController, hint: '1e-6', keyboardType: TextInputType.number) else _buildInputCard(title: '區間數 N', controller: _intNController, hint: '1000', keyboardType: TextInputType.number),
          const SizedBox(height: 32),
          SizedBox(height: 40, child: ElevatedButton(onPressed: _isIntLoading ? null : _calculateIntegral, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade50), child: _isIntLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.indigo)) : const Text('計算積分', style: TextStyle(fontSize: 16, color: Colors.indigo)))),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(12), width: double.infinity, decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)), child: SelectableText("結果: $_intResult", style: const TextStyle(fontSize: 18, fontFamily: 'Monospace'))),
          
          const SizedBox(height: 40), const Divider(thickness: 2), const SizedBox(height: 20),
          
          const Text('數值微分 (Differentiation)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 108, 194, 201))),
          const SizedBox(height: 16),
          _buildInputCard(title: '函數 f(x)', controller: _diffFunctionController, hint: 'x^2', keyboardType: TextInputType.text),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _buildInputCard(title: '求導點 x', controller: _diffPointController, hint: '2.0', keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: _buildInputCard(title: '步長 h', controller: _diffStepController, hint: '0.0001', keyboardType: TextInputType.number))]),
          const SizedBox(height: 24),
          SizedBox(height: 40, child: ElevatedButton(onPressed: _isDiffLoading ? null : _calculateDerivative, style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 206, 252, 248)), child: _isDiffLoading ? const CircularProgressIndicator() : const Text('計算導數', style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 34, 167, 255))))),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12), width: double.infinity, decoration: BoxDecoration(color: const Color.fromRGBO(203, 248, 248, 1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color.fromARGB(255, 64, 132, 150))), child: SelectableText("結果: $_diffResult", style: const TextStyle(fontSize: 18, fontFamily: 'Monospace'))),
        ],
      ),
    );
  }
}

// --- 頁面 D: ODE 求解器 (含 RK45 & 相圖) ---
class OdePage extends StatefulWidget {
  const OdePage({super.key});
  @override
  State<OdePage> createState() => _OdePageState();
}

class _OdePageState extends State<OdePage> {
  final TextEditingController _expressionController = TextEditingController(text: '-1 * y');
  final TextEditingController _t0Controller = TextEditingController(text: '0.0'); 
  final TextEditingController _y0Controller = TextEditingController(text: '[1.0, 0.0]'); 
  final TextEditingController _tEndController = TextEditingController(text: '10.0');
  final TextEditingController _nStepsController = TextEditingController(text: '1000'); 
  final TextEditingController _displayStepController = TextEditingController(text: '10'); 
  final TextEditingController _orderController = TextEditingController(text: '2'); 
  final TextEditingController _toleranceController = TextEditingController(text: '1e-6'); 

  ODEMethod _selectedMethod = ODEMethod.euler;
  List<List<double>> _displayData = []; 
  List<FlSpot> _chartSpots = []; 
  String _status = '點擊計算以求解 dy/dt = f(t, y)';
  bool _isLoading = false;
  bool _isPhaseSpace = false; // 控制相圖顯示

  String _convertNthOrderToSystem(int order, String expressionF) {
      if (order <= 0) return '';
      List<String> systemExpressions = [];
      for(int i = 0; i < order - 1; i++) systemExpressions.add('y${i + 1}'); 
      systemExpressions.add(expressionF); 
      return systemExpressions.join(', ');
  }

  Future<void> _calculateODE() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _status = '計算中...'; _displayData = []; _chartSpots = []; });

    try {
      final int order = int.parse(_orderController.text); 
      final int requiredDimension = order; 
      final String expressionF = _expressionController.text;
      final double t0 = double.parse(_t0Controller.text);
      final double tEnd = double.parse(_tEndController.text);
      final int nSteps = int.parse(_nStepsController.text);
      final int sampleStep = int.parse(_displayStepController.text); 
      final double tolerance = double.tryParse(_toleranceController.text) ?? 1e-6;

      final List<double> y0_input = (jsonDecode(_y0Controller.text) as List).map((e) => (e as num).toDouble()).toList(); 
      if (y0_input.length != requiredDimension) throw Exception("初始向量長度必須等於 ODE 階數 $order");

      final String vectorFieldExpression = _convertNthOrderToSystem(order, expressionF);
      final List<List<double>> rawData = await solveODE(
        expression: vectorFieldExpression, t0: t0, y0: y0_input, tEnd: tEnd, nSteps: nSteps, 
        method: _selectedMethod, tolerance: tolerance
      );

      List<List<double>> filteredData = [];
      List<FlSpot> spots = [];

      if (rawData.isNotEmpty) {
        for (int i = 0; i < rawData.length; i++) {
          if (i % sampleStep == 0 || i == rawData.length - 1) {
            filteredData.add(rawData[i]);
            double xVal, yVal;
            if (_isPhaseSpace) {
              if (rawData[i].length > 2) { xVal = rawData[i][1]; yVal = rawData[i][2]; } // Position vs Velocity
              else { xVal = rawData[i][0]; yVal = rawData[i][1]; } 
            } else {
              xVal = rawData[i][0]; yVal = rawData[i][1]; // Time vs Position
            }
            spots.add(FlSpot(xVal, yVal));
          }
        }
      }

      setState(() { _displayData = filteredData; _chartSpots = spots; _status = '求解完成。總步數: ${rawData.length}'; _isLoading = false; });
    } catch (e) {
      setState(() { _status = '錯誤: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('常微分方程求解器 (ODE Solver)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _buildInputCard(title: 'ODE 階數 N', controller: _orderController, hint: '2', keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: _buildInputCard(title: '顯示間隔', controller: _displayStepController, hint: '10', keyboardType: TextInputType.number))]),
          const SizedBox(height: 12),
          _buildInputCard(title: '最高階導數 F', controller: _expressionController, hint: '-1*y', keyboardType: TextInputType.text),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _buildInputCard(title: '起始時間 t₀', controller: _t0Controller, hint: '0.0', keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: _buildInputCard(title: '初始向量 y₀', controller: _y0Controller, hint: '[1.0, 0.0]', keyboardType: TextInputType.text))]),
          const SizedBox(height: 12),
          
          // --- 這裡根據方法顯示不同參數 ---
          DropdownButton<ODEMethod>(value: _selectedMethod, isExpanded: true, items: ODEMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(), onChanged: (v) => setState(() => _selectedMethod = v!)),
          const SizedBox(height: 12),
          
          if (_selectedMethod == ODEMethod.adaptiveRk45) ...[
             _buildInputCard(title: '結束時間 t_end', controller: _tEndController, hint: '10.0', keyboardType: TextInputType.number),
             const SizedBox(height: 12),
             _buildInputCard(title: '容許誤差 Tolerance', controller: _toleranceController, hint: '1e-6', keyboardType: TextInputType.number),
          ] else ...[
             Row(children: [
               Expanded(child: _buildInputCard(title: '結束時間 t_end', controller: _tEndController, hint: '10.0', keyboardType: TextInputType.number)),
               const SizedBox(width: 12),
               Expanded(child: _buildInputCard(title: '計算步數 N', controller: _nStepsController, hint: '1000', keyboardType: TextInputType.number)),
             ]),
          ],

          const SizedBox(height: 24),
          ElevatedButton(onPressed: _isLoading ? null : _calculateODE, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('開始求解 & 繪圖', style: TextStyle(fontSize: 16))),
          const SizedBox(height: 20),
          Text(_status, style: TextStyle(fontWeight: FontWeight.bold, color: _isLoading ? Colors.blue : Colors.black87)),
          const SizedBox(height: 20),

          if (_chartSpots.isNotEmpty) ...[
             // 相圖切換開關
             SwitchListTile(
               title: const Text('顯示模式'),
               subtitle: Text(_isPhaseSpace ? '相圖 (Phase Space): y\' vs y' : '時域圖 (Time Domain): y vs t'),
               value: _isPhaseSpace,
               activeColor: Colors.indigo,
               onChanged: (val) {
                 setState(() { _isPhaseSpace = val; _calculateODE(); });
               },
             ),
             const SizedBox(height: 10),
             Container(
               height: 300,
               padding: const EdgeInsets.only(right: 16, top: 10),
               decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
               child: LineChart(LineChartData(
                 gridData: FlGridData(show: true, drawVerticalLine: true),
                 titlesData: FlTitlesData(
                   bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text(val.toStringAsFixed(1), style: const TextStyle(fontSize: 10))), axisNameWidget: Text(_isPhaseSpace ? '位置 y' : '時間 t')),
                   leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text(val.toStringAsFixed(1), style: const TextStyle(fontSize: 10))), axisNameWidget: Text(_isPhaseSpace ? '速度 y\'' : '位置 y')),
                   topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                   rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 ),
                 lineBarsData: [LineChartBarData(spots: _chartSpots, isCurved: true, color: Colors.indigo, barWidth: 2, isStrokeCapRound: true, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Colors.indigo.withValues(alpha: 0.1)))],
               )),
             ),
             const SizedBox(height: 20),
          ],
          _buildDataTable(),
        ],
      ),
    );
  }
  
  Widget _buildDataTable() {
    if (_displayData.isEmpty) return Container();
    final int dimension = _displayData[0].length - 1;
    final String yTitle = (dimension > 1) ? 'y_n (向量)' : 'y_n';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('採樣數據列表:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DataTable(columnSpacing: 20, horizontalMargin: 0, columns: [const DataColumn(label: Text('t')), DataColumn(label: Text(yTitle))], rows: _displayData.take(100).map((row) {
             final tVal = row[0].toStringAsFixed(4);
             final List<double> yComponents = row.sublist(1).cast<double>();
             final String yStr = (yComponents.length == 1) ? yComponents[0].toStringAsFixed(4) : '[${yComponents.map((val) => val.toStringAsFixed(4)).join(', ')}]';
             return DataRow(cells: [DataCell(Text(tVal)), DataCell(Text(yStr))]);
          }).toList())
    ]);
  }
}