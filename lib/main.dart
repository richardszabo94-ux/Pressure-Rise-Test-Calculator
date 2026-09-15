import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const PressureRiseApp());
}

// Globális lista a mentett hőcserélők tárolásához a memóriában
List<Map<String, dynamic>> savedHeatExchangers = [];

class PressureRiseApp extends StatelessWidget {
  const PressureRiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pressure Rise Test Calculator',
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
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Előkalkuláció'),
      const BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Hőcserélők'),
      if (_isMeasureTabVisible)
        const BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Mérés végzése'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? 'Előkalkuláció'
              : _currentIndex == 1
                  ? 'Mentett hőcserélők'
                  : 'Mérés: $_measPos',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const CalcScreen(),
          SavedListScreen(onMeasureRequested: _openMeasureTab),
          if (_isMeasureTabVisible)
            MeasureScreen(
              pos: _measPos,
              volume: _measVolume,
              gauge: _measGauge,
              onClose: _hideMeasureTab,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
  const CalcScreen({super.key});

  @override
  State<CalcScreen> createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  final _posCtrl = TextEditingController();
  final _snCtrl = TextEditingController();
  final _volCtrl = TextEditingController();
  final _vacCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  String? _selectedMedium;
  String? _selectedGauge;
  bool _isTimeMode = true;

  Map<String, dynamic>? _calcResult;
  final double pAtm = 1013.25;

  double _getMediumRate(String med) {
    if (med == 'Steam') return 0.001;        // Leybold Vapor-tight: < 1e-3
    if (med == 'Oil') return 0.00001;        // Leybold Oil-tight: < 1e-5
    return 0.01;                             // Leybold Water-tight: < 1e-2
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
      _showError('Válasszon köpeny oldali közeget!');
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

    final qLReq = _getMediumRate(_selectedMedium!);
    final qLEffective = qLReq * driving;
    final dp = _getGaugeDp(_selectedGauge!);
    final medLabel = _getMediumLabel(_selectedMedium!);

    double incHours = 2.0;
    if (v > 10000) incHours = 4.0;
    if (v > 25000) incHours = 6.0;

    if (_isTimeMode) {
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
              'Műszer küszöb: $dp mbar\nEnnyi idő szükséges a $medLabel igazolásához.',
          'incubation': incHours,
          'suggestion': optText,
          'summary': '${tHours.toStringAsFixed(1)} óra szükséges',
        };
      });
    } else {
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
    }
  }

  void _saveRecord() {
    if (_calcResult == null) return;

    final pos = _posCtrl.text.trim();
    final sn = _snCtrl.text.trim().isEmpty ? 'N/A' : _snCtrl.text.trim();
    final v = double.parse(_volCtrl.text.trim());

    savedHeatExchangers.add({
      'pos': pos,
      'sn': sn,
      'v': v,
      'med': _selectedMedium,
      'gauge': _selectedGauge,
      'res': _calcResult!['summary'],
      'date': DateTime.now().toString().substring(0, 10),
    });

    setState(() {
      _posCtrl.clear();
      _snCtrl.clear();
      _volCtrl.clear();
      _vacCtrl.clear();
      _timeCtrl.clear();
      _selectedMedium = null;
      _selectedGauge = null;
      _calcResult = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('A(z) "$pos" pozíciójú hőcserélő sikeresen elmentve!'),
        backgroundColor: Colors.green,
      ),
    );
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
                    DropdownMenuItem(value: 'Steam', child: Text('Steam | Vapor-tight (10⁻³ mbar·l/s)')),
                    DropdownMenuItem(value: 'Water', child: Text('Water | Water-tight (10⁻² mbar·l/s)')),
                    DropdownMenuItem(value: 'Glycol', child: Text('Glycol | Water-tight (10⁻² mbar·l/s)')),
                    DropdownMenuItem(value: 'CHW', child: Text('CHW | Water-tight (10⁻² mbar·l/s)')),
                    DropdownMenuItem(value: 'Oil', child: Text('Oil | Oil-tight (10⁻⁵ mbar·l/s)')),
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
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Szükséges idő')),
                    ButtonSegment(value: false, label: Text('Adott idő alatti hiba')),
                  ],
                  selected: {_isTimeMode},
                  onSelectionChanged: (set) => setState(() => _isTimeMode = set.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _vacCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Vákuum mértéke [mbar] *', border: OutlineInputBorder()),
                ),
                if (!_isTimeMode) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _timeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Vizsgálati idő [óra] *', border: OutlineInputBorder()),
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
                      label: const Text('Hőcserélő mentése (Adatok nullázása)'),
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
  List<Map<String, dynamic>> _grid = [];
  Map<String, dynamic>? _evalResult;

  @override
  void initState() {
    super.initState();
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
      return {
        'label': i == 0 ? '0. óra (Kezdet)' : (i == count - 1 ? '${currentH}h (Záró)' : '${currentH}h'),
        'p': TextEditingController(),
        't': TextEditingController(),
      };
    });
    setState(() => _evalResult = null);
  }

  void _evaluate() {
    if (_grid.length < 2) return;
    final p1 = double.tryParse(_grid.first['p'].text);
    final t1Raw = double.tryParse(_grid.first['t'].text);
    final p2 = double.tryParse(_grid.last['p'].text);
    final t2Raw = double.tryParse(_grid.last['t'].text);

    if (p1 == null || p2 == null || t1Raw == null || t2Raw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A kezdő (0h) és a záró pont p és T értékét kötelező kitölteni!')),
      );
      return;
    }

    final v = widget.volume ?? 11550.0;
    final hours = double.tryParse(_durCtrl.text.trim()) ?? 24.0;
    final tSec = hours * 3600.0;

    final t1 = t1Raw + 273.15;
    final t2 = t2Raw + 273.15;

    // Gay-Lussac korrekció
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
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Hőcserélő: ${widget.pos}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text('Bezárás', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Időtartam [h]', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _generateGrid, child: const Text('Rács újra')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mérési napló (${_grid.length} pont)', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._grid.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 80, child: Text(row['label'], style: const TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(
                            child: TextField(
                              controller: row['p'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'p [mbar]', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: row['t'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'T [°C]', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
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
          const SizedBox(height: 10),
          Card(
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mért qL: ${_evalResult!['qL']} mbar·l/s',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                  const SizedBox(height: 6),
                  Text('Hőmérséklet-korrigált valós emelkedés: ${_evalResult!['dpEff']} mbar'),
                  Text('Termikus látszólagos hatás: ${_evalResult!['dpThermal']} mbar'),
                  Text('Ekvivalens átmenő furatátmérő: ~${_evalResult!['dMm']} mm'),
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
  void _delete(int index) {
    setState(() {
      savedHeatExchangers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (savedHeatExchangers.isEmpty) {
      return const Center(child: Text('Nincsenek mentett hőcserélők.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: savedHeatExchangers.length,
      itemBuilder: (context, i) {
        final it = savedHeatExchangers[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(it['pos'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            subtitle: Text('${it['v']} L | ${it['med']} | ${it['gauge']}\n${it['res']} (${it['date']})'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                  tooltip: 'Méréshez betöltés',
                  onPressed: () => widget.onMeasureRequested(it['pos'], it['v'].toDouble(), it['gauge']),
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
