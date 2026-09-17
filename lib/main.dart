import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PressureRiseApp());
}

class PressureRiseApp extends StatelessWidget {
  const PressureRiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pressure Rise Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          primary: const Color(0xFF1565C0),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isMeasureTabVisible = false;

  String _measPos = "";
  double? _measVolume;
  String? _measGauge;

  final GlobalKey<_SavedListScreenState> _savedListKey = GlobalKey<_SavedListScreenState>();
  final GlobalKey<_MeasureScreenState> _measureScreenKey = GlobalKey<_MeasureScreenState>();

  @override
  void initState() {
    super.initState();
    _checkActiveMeasurement();
  }

  Future<void> _checkActiveMeasurement() async {
    final prefs = await SharedPreferences.getInstance();
    final activeData = prefs.getString('active_measurement');
    if (activeData != null) {
      final decoded = jsonDecode(activeData);
      setState(() {
        _measPos = decoded['pos'] ?? '';
        _measVolume = (decoded['volume'] as num?)?.toDouble();
        _measGauge = decoded['gauge'];
        _isMeasureTabVisible = true;
      });
    }
  }

  void _openMeasureTab(String pos, double volume, String gauge) {
    setState(() {
      _measPos = pos;
      _measVolume = volume;
      _measGauge = gauge;
      _isMeasureTabVisible = true;
      _currentIndex = 2;
    });
  }

  void _hideMeasureTab() {
    setState(() {
      _isMeasureTabVisible = false;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      CalcScreen(onSaved: () => _savedListKey.currentState?.reload()),
      SavedListScreen(key: _savedListKey, onMeasureRequested: _openMeasureTab),
      if (_isMeasureTabVisible)
        MeasureScreen(
          key: _measureScreenKey,
          pos: _measPos,
          volume: _measVolume,
          gauge: _measGauge,
          onClose: _hideMeasureTab,
        ),
      const InfoScreen(),
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Kalkuláció'),
      const BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Hőcserélők'),
      if (_isMeasureTabVisible)
        const BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Mérés'),
      const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Módszertan'),
    ];

    if (_currentIndex >= pages.length) {
      _currentIndex = pages.length - 1;
    }

    String getTitle() {
      if (_currentIndex == 0) return 'Előkalkuláció';
      if (_currentIndex == 1) return 'Mentett hőcserélők';
      if (_isMeasureTabVisible && _currentIndex == 2) return 'Mérés: $_measPos';
      return 'Számítási módszertan és képletek';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          getTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            _savedListKey.currentState?.reload();
          }
        },
        selectedItemColor: const Color(0xFF1565C0),
        items: navItems,
      ),
    );
  }
}

// -------------------------------------------------------------
// 1. FÜL: ELŐKALKULÁCIÓ
// -------------------------------------------------------------
class CalcScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const CalcScreen({super.key, required this.onSaved});

  @override
  State<CalcScreen> createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  final _posCtrl = TextEditingController();
  final _snCtrl = TextEditingController();
  final _volCtrl = TextEditingController();
  final _vacCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _defectSizeCtrl = TextEditingController();

  String? _selectedMedium;
  String? _selectedGauge;
  String _calcMode = 'time_by_medium';

  Map<String, dynamic>? _calcResult;
  final double pAtm = 1013.25;

  double _getMediumRate(String med) {
    if (med == 'Steam') return 0.001;
    if (med == 'Oil') return 0.00001;
    return 0.01;
  }

  String _getMediumLabel(String med) {
    if (med == 'Steam') return 'gőztömörség (Vapor-tight)';
    if (med == 'Oil') return 'olajtömörség (Oil-tight)';
    return 'víztömörség (Water-tight)';
  }

  double _getGaugeDp(String gauge) {
    if (gauge == 'Pfeiffer') return 0.1;
    if (gauge == 'Wika10') return 10.0;
    return 16.0;
  }

  void _calculate() {
    final pos = _posCtrl.text.trim();
    final v = double.tryParse(_volCtrl.text.trim());
    final vac = double.tryParse(_vacCtrl.text.trim());

    if (pos.isEmpty) {
      _showError('A Pozíció szám megadása kötelező!');
      return;
    }
    if (v == null || v <= 0) {
      _showError('Érvényes köpenytérfogat szükséges!');
      return;
    }
    if (_selectedMedium == null) {
      _showError('Válasszon közeget!');
      return;
    }
    if (_selectedGauge == null) {
      _showError('Válasszon mérőműszert!');
      return;
    }
    if (vac == null || vac <= 0) {
      _showError('Érvényes vákuumszint szükséges!');
      return;
    }

    double driving = (pAtm - vac) / pAtm;
    if (driving <= 0.01) driving = 0.01;

    final dp = _getGaugeDp(_selectedGauge!);
    final medLabel = _getMediumLabel(_selectedMedium!);

    double incHours = 2.0;
    if (v > 10000) incHours = 4.0;
    if (v > 25000) incHours = 6.0;

    if (_calcMode == 'time_by_medium') {
      final qLReq = _getMediumRate(_selectedMedium!);
      final qLEffective = qLReq * driving;
      final tSec = (v * dp) / qLEffective;
      final tHours = tSec / 3600.0;
      final tDays = tSec / 86400.0;

      String? optText;
      if (_selectedGauge!.startsWith('Wika')) {
        final tPfSec = (v * 0.1) / qLEffective;
        optText = 'Pfeiffer műszerrel (Δp=0.1 mbar) ez az idő lecsökkenthető: '
            '${(tPfSec / 3600).toStringAsFixed(1)} órára (${(tPfSec / 86400).toStringAsFixed(1)} nap)!';
      }

      setState(() {
        _calcResult = {
          'highlight': '${tHours.toStringAsFixed(1)} óra (${tDays.toStringAsFixed(1)} nap)',
          'details': 'Létrehozott vákuum: $vac mbar (Hajtóerő: ${(driving * 100).toStringAsFixed(1)}%)\n'
              'Műszer küszöb: $dp mbar\nEnnyi idő kell a $medLabel igazolásához.',
          'incubation': incHours,
          'suggestion': optText,
          'summary': '${tHours.toStringAsFixed(1)} óra szükséges',
        };
      });
    } else if (_calcMode == 'defect_by_time') {
      final hours = double.tryParse(_timeCtrl.text.trim());
      if (hours == null || hours <= 0) {
        _showError('Adja meg a tervezett vizsgálati időt!');
        return;
      }
      final tSec = hours * 3600.0;
      final qLDetected = ((v * dp) / tSec) / driving;
      final dMm = 0.1 * sqrt(qLDetected / 0.133);

      setState(() {
        _calcResult = {
          'highlight': 'Max. ~${dMm.toStringAsFixed(3)} mm ekv. hiba',
          'details': 'A(z) $hours órás vizsgálat alatt detektálható legkisebb szivárgás: '
              '${qLDetected.toStringAsFixed(5)} mbar·l/s.',
          'incubation': incHours,
          'suggestion': null,
          'summary': 'Max. ~${dMm.toStringAsFixed(3)} mm hiba (${hours}h)',
        };
      });
    } else {
      final targetD = double.tryParse(_defectSizeCtrl.text.trim());
      if (targetD == null || targetD <= 0) {
        _showError('Adja meg az elvárt hibaméretet [mm] (pl. 0.05)!');
        return;
      }
      final qLTarget = 0.133 * pow(targetD / 0.1, 2);
      final qLEffective = qLTarget * driving;
      final tSec = (v * dp) / qLEffective;
      final tHours = tSec / 3600.0;
      final tDays = tSec / 86400.0;

      String? optText;
      if (_selectedGauge!.startsWith('Wika')) {
        final tPfSec = (v * 0.1) / qLEffective;
        optText = 'Pfeiffer műszerrel (Δp=0.1 mbar) ez az idő lecsökkenthető: '
            '${(tPfSec / 3600).toStringAsFixed(1)} órára (${(tPfSec / 86400).toStringAsFixed(1)} nap)!';
      }

      setState(() {
        _calcResult = {
          'highlight': '${tHours.toStringAsFixed(1)} óra (${tDays.toStringAsFixed(1)} nap)',
          'details': 'Elvárt kimutatandó hiba: Ø $targetD mm\n'
              'Ekvivalens ráta: ${qLTarget.toStringAsFixed(5)} mbar·l/s\n'
              'Műszer küszöb: $dp mbar\nEnnyi idő kell a hiba biztos kimutatásához.',
          'incubation': incHours,
          'suggestion': optText,
          'summary': '${tHours.toStringAsFixed(1)}h (Ø ${targetD}mm)',
        };
      });
    }
  }

  Future<void> _saveRecord() async {
    if (_calcResult == null) return;

    final pos = _posCtrl.text.trim();
    final sn = _snCtrl.text.trim().isEmpty ? 'N/A' : _snCtrl.text.trim();
    final v = double.parse(_volCtrl.text.trim());

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_hx_list') ?? '[]';
    final List<dynamic> list = jsonDecode(raw);

    list.add({
      'pos': pos,
      'sn': sn,
      'v': v,
      'med': _selectedMedium,
      'gauge': _selectedGauge,
      'res': _calcResult!['summary'],
      'date': DateTime.now().toString().substring(0, 10),
    });

    await prefs.setString('saved_hx_list', jsonEncode(list));
    widget.onSaved();

    setState(() {
      _posCtrl.clear();
      _snCtrl.clear();
      _volCtrl.clear();
      _vacCtrl.clear();
      _timeCtrl.clear();
      _defectSizeCtrl.clear();
      _selectedMedium = null;
      _selectedGauge = null;
      _calcResult = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A(z) "$pos" pozíciójú hőcserélő elmentve a telefonra!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hőcserélő alapadatok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _posCtrl,
                        decoration: const InputDecoration(labelText: 'Pozíció szám *', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _snCtrl,
                        decoration: const InputDecoration(labelText: 'Gyári szám', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _volCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Köpeny térfogat [liter] *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Köpeny oldali közeg *', border: OutlineInputBorder()),
                  value: _selectedMedium,
                  items: const [
                    DropdownMenuItem(value: 'Steam', child: Text('Steam | Vapor-tight (10⁻³)')),
                    DropdownMenuItem(value: 'Water', child: Text('Water | Water-tight (10⁻²)')),
                    DropdownMenuItem(value: 'Glycol', child: Text('Glycol | Water-tight (10⁻²)')),
                    DropdownMenuItem(value: 'CHW', child: Text('CHW | Water-tight (10⁻²)')),
                    DropdownMenuItem(value: 'Oil', child: Text('Oil | Oil-tight (10⁻⁵)')),
                  ],
                  onChanged: (v) => setState(() => _selectedMedium = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Vákuummérő óra *', border: OutlineInputBorder()),
                  value: _selectedGauge,
                  items: const [
                    DropdownMenuItem(value: 'Pfeiffer', child: Text('Pfeiffer TPG 202 (Δp = 0.1 mbar)')),
                    DropdownMenuItem(value: 'Wika10', child: Text('WIKA Kl. 1.0 (Δp = 10 mbar)')),
                    DropdownMenuItem(value: 'Wika16', child: Text('WIKA Kl. 1.6 (Δp = 16 mbar)')),
                  ],
                  onChanged: (v) => setState(() => _selectedGauge = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'time_by_medium', label: Text('Közeg')),
                    ButtonSegment(value: 'defect_by_time', label: Text('Idő hiba')),
                    ButtonSegment(value: 'time_by_defect', label: Text('Hibaméret')),
                  ],
                  selected: {_calcMode},
                  onSelectionChanged: (set) => setState(() => _calcMode = set.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _vacCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Vákuum mértéke [mbar] *', border: OutlineInputBorder()),
                ),
                if (_calcMode == 'defect_by_time') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _timeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Vizsgálati idő [óra] *', border: OutlineInputBorder()),
                  ),
                ],
                if (_calcMode == 'time_by_defect') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _defectSizeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Elvárt hibaméret [mm] *', hintText: 'pl. 0.05', border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                    onPressed: _calculate,
                    child: const Text('Előkalkuláció futtatása', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
        if (_calcResult != null) ...[
          const SizedBox(height: 10),
          Card(
            color: const Color(0xFFE3F2FD),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_calcResult!['highlight'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1))),
                  const SizedBox(height: 8),
                  Text(_calcResult!['details']),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      'Szükséges inkubációs idő: ~${_calcResult!['incubation']} óra (felületi adszorpció stabilizálódásáig).',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20)),
                    ),
                  ),
                  if (_calcResult!['suggestion'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(6)),
                      child: Text(_calcResult!['suggestion'], style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037))),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1565C0)),
                      onPressed: _saveRecord,
                      icon: const Icon(Icons.save),
                      label: const Text('Hőcserélő mentése a telefonra'),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// -------------------------------------------------------------
// 2. FÜL: MÉRÉS VÉGZÉSE
// -------------------------------------------------------------
class MeasureScreen extends StatefulWidget {
  final String pos;
  final double? volume;
  final String? gauge;
  final VoidCallback onClose;

  const MeasureScreen({
    super.key,
    required this.pos,
    this.volume,
    this.gauge,
    required this.onClose,
  });

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  final _durCtrl = TextEditingController(text: '24');
  DateTime _startTime = DateTime.now();
  List<Map<String, dynamic>> _grid = [];
  Map<String, dynamic>? _evalResult;

  @override
  void initState() {
    super.initState();
    _loadOrCreateActiveMeasurement();
  }

  String _formatDateTime(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m.$d. $h:$min';
  }

  Future<void> _loadOrCreateActiveMeasurement() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('active_measurement');

    if (savedJson != null) {
      final data = jsonDecode(savedJson);
      if (data['pos'] == widget.pos) {
        _durCtrl.text = data['duration'] ?? '24';
        if (data['startTime'] != null) {
          _startTime = DateTime.tryParse(data['startTime']) ?? DateTime.now();
        }
        final List<dynamic> rows = data['rows'] ?? [];
        setState(() {
          _grid = rows.map((r) => {
            'label': r['label'],
            'targetTime': r['targetTime'] ?? '',
            'p': TextEditingController(text: r['p']),
            't': TextEditingController(text: r['t']),
          }).toList();
        });
        return;
      }
    }
    _generateGrid();
  }

  void _generateGrid() {
    final hours = double.tryParse(_durCtrl.text.trim()) ?? 24.0;
    double step = 1.0;
    if (hours <= 4) step = 0.5;
    else if (hours <= 12) step = 1.0;
    else if (hours <= 24) step = 2.0;
    else step = 4.0;

    final count = (hours / step).floor() + 1;
    _grid = List.generate(count, (i) {
      double currentH = i * step;
      if (currentH > hours) currentH = hours;

      final targetDate = _startTime.add(Duration(minutes: (currentH * 60).round()));
      final timeStr = _formatDateTime(targetDate);
      String stage = i == 0 ? 'Kezdet' : (i == count - 1 ? 'Záró' : '${currentH}h');

      return {
        'label': '$timeStr\n($stage)',
        'targetTime': timeStr,
        'p': TextEditingController(),
        't': TextEditingController(),
      };
    });
    setState(() => _evalResult = null);
    _saveProgressQuietly();
  }

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null) return;

    setState(() {
      _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
    _generateGrid();
  }

  void _setStartTimeNow() {
    setState(() {
      _startTime = DateTime.now();
    });
    _generateGrid();
  }

  Future<void> _saveProgressQuietly() async {
    final prefs = await SharedPreferences.getInstance();
    final rowsData = _grid.map((r) => {
      'label': r['label'],
      'targetTime': r['targetTime'],
      'p': r['p'].text,
      't': r['t'].text,
    }).toList();

    await prefs.setString('active_measurement', jsonEncode({
      'pos': widget.pos,
      'volume': widget.volume,
      'gauge': widget.gauge,
      'duration': _durCtrl.text.trim(),
      'startTime': _startTime.toIso8601String(),
      'rows': rowsData,
    }));
  }

  Future<void> saveMeasurementProgress() async {
    await _saveProgressQuietly();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktuális pontok és időbélyegek elmentve!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _resetMeasurement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_measurement');
    _startTime = DateTime.now();
    _generateGrid();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mérési adatok alaphelyzetbe állítva!')),
      );
    }
  }

  void _evaluate() {
    _saveProgressQuietly();

    Map<String, dynamic>? firstFilled;
    for (var r in _grid) {
      if (r['p'].text.isNotEmpty && r['t'].text.isNotEmpty) {
        firstFilled = r;
        break;
      }
    }

    Map<String, dynamic>? lastFilled;
    for (var r in _grid.reversed) {
      if (r['p'].text.isNotEmpty && r['t'].text.isNotEmpty) {
        lastFilled = r;
        break;
      }
    }

    if (firstFilled == null || lastFilled == null || firstFilled == lastFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Legalább 2 kitöltött mérési pont szükséges a trendhez!')),
      );
      return;
    }

    final p1 = double.tryParse(firstFilled['p'].text);
    final t1Raw = double.tryParse(firstFilled['t'].text);
    final p2 = double.tryParse(lastFilled['p'].text);
    final t2Raw = double.tryParse(lastFilled['t'].text);

    if (p1 == null || p2 == null || t1Raw == null || t2Raw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Érvénytelen számformátum a beírt pontoknál!')),
      );
      return;
    }

    final v = widget.volume ?? 11550.0;
    final hours = double.tryParse(_durCtrl.text.trim()) ?? 24.0;
    final tSec = hours * 3600.0;

    final t1 = t1Raw + 273.15;
    final t2 = t2Raw + 273.15;

    final p2Corrected = p2 * (t1 / t2);
    final dpEffective = max(0.0, p2Corrected - p1);

    double driving = (1013.25 - p1) / 1013.25;
    if (driving <= 0.01) driving = 0.01;

    final qL = ((v * dpEffective) / tSec) / driving;
    final dMm = qL > 0 ? 0.1 * sqrt(qL / 0.133) : 0.0;
    final dpThermal = p1 * ((t2 / t1) - 1.0);

    setState(() {
      _evalResult = {
        'qL': qL.toStringAsFixed(5),
        'dMm': dMm.toStringAsFixed(3),
        'dpEff': dpEffective.toStringAsFixed(2),
        'dpRaw': (p2 - p1).toStringAsFixed(2),
        'dpThermal': (dpThermal > 0 ? '+$dpThermal' : dpThermal.toStringAsFixed(2)),
        'range': '${firstFilled!['targetTime']} ➔ ${lastFilled!['targetTime']}',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = double.tryParse(_durCtrl.text.trim()) ?? 24.0;
    final endTime = _startTime.add(Duration(minutes: (hours * 60).round()));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Hőcserélő: ${widget.pos}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Mérés nullázása',
              icon: const Icon(Icons.refresh, color: Colors.orange),
              onPressed: _resetMeasurement,
            ),
            IconButton(
              tooltip: 'Bezárás',
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: widget.onClose,
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mérési időkeret és ütemezés', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Kezdés:', style: TextStyle(fontSize: 10, color: Colors.black54)),
                            Text(_formatDateTime(_startTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Várható zárás:', style: TextStyle(fontSize: 10, color: Color(0xFF1B5E20))),
                            Text(_formatDateTime(endTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B5E20))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _setStartTimeNow,
                      icon: const Icon(Icons.access_time, size: 15),
                      label: const Text('Kezdés: Most', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.calendar_month, size: 15),
                      label: const Text('Egyéni időpont', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _durCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Időtartam [h]', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _generateGrid, child: const Text('Ütemezés')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mintavételi napló (${_grid.length} pont)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: saveMeasurementProgress,
                      icon: const Icon(Icons.save_as, size: 15),
                      label: const Text('Részleges mentés', style: TextStyle(fontSize: 11)),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                ..._grid.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 78,
                            child: Text(
                              row['label'],
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: row['p'],
                              onChanged: (_) => _saveProgressQuietly(),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: 'p [mbar]',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: row['t'],
                              onChanged: (_) => _saveProgressQuietly(),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: 'T [°C]',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                    onPressed: _evaluate,
                    child: const Text('Mérés kiértékelése', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_evalResult != null) ...[
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mért tartomány: ${_evalResult!['range']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Mért qL: ${_evalResult!['qL']} mbar·l/s',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                  const SizedBox(height: 4),
                  Text('Hőmérséklet-korrigált valós emelkedés: ${_evalResult!['dpEff']} mbar', style: const TextStyle(fontSize: 12)),
                  Text('Termikus látszólagos hatás: ${_evalResult!['dpThermal']} mbar', style: const TextStyle(fontSize: 12)),
                  Text('Ekvivalens átmenő furatátmérő: ~${_evalResult!['dMm']} mm', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// -------------------------------------------------------------
// 3. FÜL: MENTETT HŐCSERÉLŐK
// -------------------------------------------------------------
class SavedListScreen extends StatefulWidget {
  final Function(String pos, double v, String gauge) onMeasureRequested;

  const SavedListScreen({super.key, required this.onMeasureRequested});

  @override
  State<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends State<SavedListScreen> {
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_hx_list') ?? '[]';
    setState(() {
      _items = jsonDecode(raw);
    });
  }

  Future<void> _delete(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _items.removeAt(index);
    await prefs.setString('saved_hx_list', jsonEncode(_items));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(child: Text('Nincsenek mentett hőcserélők a telefonon.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final it = _items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(it['pos'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            subtitle: Text('${it['v']} L | ${it['med']} | ${it['gauge']}\n${it['res']} (${it['date']})'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                  tooltip: 'Mérés betöltése',
                  onPressed: () => widget.onMeasureRequested(it['pos'], (it['v'] as num).toDouble(), it['gauge']),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _delete(i),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------
// 4. FÜL: SZÁMÍTÁSI MÓDSZERTAN ÉS KÉPLETEK (MÉRNÖKI HÁTTÉRREL)
// -------------------------------------------------------------
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildInfoCard(
          title: '1. Alapvető gáztörvény és szivárgási ráta',
          formula: 'qL = (V · Δp) / t',
          explanation: 'Ahol:\n'
              '• qL: Szivárgási ráta [mbar·l/s]\n'
              '• V: Köpenytérfogat [liter]\n'
              '• Δp: Észlelt valós nyomásnövekedés [mbar]\n'
              '• t: Mérési időtartam másodpercben [s]\n\n'
              'A kalkuláció a megengedett szivárgásból és a műszer felbontásából (küszöbérték) határozza meg a szükséges időt: t = (V · Δp) / qL',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          title: '2. Légköri hajtóerő korrekció (Driving Factor)',
          formula: 'f_hajtó = (p_atm - p_vac) / p_atm',
          explanation: 'Ahol:\n'
              '• p_atm: Standard légköri nyomás (1013.25 mbar)\n'
              '• p_vac: Létrehozott belső vákuumszint [mbar]\n\n'
              'A valós vákuumszint figyelembevételével a kalkuláció az effektív szivárgási sebességgel számol:\n'
              'qL,eff = qL,req · f_hajtó',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          title: '3. Áramlási rezsimek és a modell konzervatív jellege',
          formula: 'Biztonsági döntés: Lineáris modell alkalmazása',
          explanation: 'A valós szivárgási csatorna geometriája a terepen ismeretlen:\n\n'
              '• Fojtott (szonikus) áramlás: Szűk lyuknál levegő esetén a kritikus nyomásviszony ~0.528. Ha a belső nyomás < 535 mbar, az áramlás eléri a hangsebességet, a tömegáram konstanssá válik (f = 1.0).\n\n'
              '• Hosszú mikrokapilláris (Poiseuille): Hegesztési varrathiba esetén a lamináris áramlás hajtóereje a nyomások négyzetével arányos: f ~ (p_atm² - p_vac²) / p_atm².\n\n'
              '• Miért a lineáris modellt használjuk? Sekély vákuumnál (400–800 mbar) a lineáris arányosítás alulbecsüli a hajtóerőt, így HOSSZABB mérési időt ír elő. Ez a minőségbiztosításban a BIZTONSÁGOS (konzervatív) oldal: megakadályozza a szivárgó berendezések téves megfelelőségi (False-Pass) átadását.',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          title: '4. Leybold tömörségi referencia határértékek',
          formula: 'Víz: 10⁻² | Gőz: 10⁻³ | Olaj: 10⁻⁵ mbar·l/s',
          explanation: 'A szabványos Leybold vákuumtechnikai osztályozás alapján:\n'
              '• Víztömör (Water-tight): qL < 0.01 mbar·l/s (Víz, glikol, hűtött víz)\n'
              '• Gőztömör (Vapor-tight): qL < 0.001 mbar·l/s (Vízgőz közegek)\n'
              '• Olajtömör (Oil-tight): qL < 0.00001 mbar·l/s (Termálolaj, nehézolaj)',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          title: '5. Ekvivalens hibaméret (Furatátmérő)',
          formula: 'd = 0.1 · √(qL / 0.133)   [mm]',
          explanation: 'A Leybold referencia szerint egy 0.1 mm átmérőjű kör keresztmetszetű átmenő hiba légköri nyomáskülönbségnél ~0.133 mbar·l/s szivárgást okoz.\n\n'
              'Ebből visszafelé számítva a mért qL-ből meghatározható a geometriai hiba nagysága, illetve fordítva: egy elvárt d_cél hibamérethez kiszámítható a szükséges tesztidő: qL = 0.133 · (d / 0.1)²',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          title: '6. Gay-Lussac termikus korrekció',
          formula: 'p2,korr = p2 · (T1 / T2)\nΔp_eff = p2,korr - p1',
          explanation: 'A gáztörvény (p/T = állandó) alapján zárt térben a hőmérséklet változása közvetlen nyomásváltozást kelt (Kelvinben számolva: T = t + 273.15).\n\n'
              '• Ha a hőmérséklet emelkedik, a gáz kitágul, és látszólagos szivárgást mutat.\n'
              '• A Gay-Lussac korrekció kivonja ezt a látszólagos termikus emelkedést, így csak a valós anyaghiányból eredő nyomásnövekedést értékeli ki.',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          title: '7. Inkubációs (felületi deszorpciós) idő',
          formula: 'V < 10m³: ~2h | V < 25m³: ~4h | V > 25m³: ~6h',
          explanation: 'A vákuum leszakítása után a fémfalak mikroszkopikus pórusaiból megindul a felületi nedvesség és gázok deszorpciója (kipárolgása). Ez az első órákban fals meredek nyomásemelkedést okoz. A hivatalos jegyzőkönyvezett mérést csak az inkubációs idő lejárta után szabad megkezdeni.',
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required String formula, required String explanation}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1565C0))),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Text(
                formula,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0D47A1)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
