import 'package:flutter/material.dart';
import '../storage.dart';
import '../notification_service.dart';

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']; // index0=weekday1

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});
  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final subjects = Storage.allSubjects();
    return Column(
      children: [
        AppBar(title: const Text('Subjects'), automaticallyImplyLeading: false),
        Expanded(
          child: subjects.isEmpty
              ? const Center(child: Text('No subjects yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: subjects.length,
                  itemBuilder: (context, i) {
                    final s = subjects[i];
                    final days = (s['days'] as List).cast<int>();
                    final everyDay = days.length == 7;
                    final timeLabel = (s['start'] as String).isNotEmpty
                        ? '${s['start']}${(s['end'] as String).isNotEmpty ? ' – ${s['end']}' : ''}'
                        : null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Color(s['color']), radius: 10),
                        title: Text(s['name']),
                        subtitle: timeLabel == null
                            ? null
                            : Text(
                                '$timeLabel · ${everyDay ? "Everyday" : days.map((d) => _dayLabels[d - 1]).join(", ")}'
                                '${s['notify'] == true ? " · 🔔 1 min before" : ""}',
                                style: const TextStyle(fontSize: 11),
                              ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () async {
                            await NotificationService.cancelWeekly('subject-${s['id']}');
                            await Storage.deleteSubject(s['id']);
                            setState(() {});
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add subject'),
            onPressed: () => _showAddSubjectSheet(context),
          ),
        ),
      ],
    );
  }

  void _showAddSubjectSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    int color = presetColors.first;
    TimeOfDay? start;
    TimeOfDay? end;
    List<int> days = [1, 2, 3, 4, 5, 6, 7];
    bool notify = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('New subject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: presetColors.map((c) {
                    return GestureDetector(
                      onTap: () => setSheet(() => color = c),
                      child: CircleAvatar(
                        backgroundColor: Color(c),
                        radius: 14,
                        child: color == c ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 9, minute: 0));
                        if (t != null) setSheet(() => start = t);
                      },
                      child: Text(start == null ? 'Start time' : start!.format(ctx)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 10, minute: 0));
                        if (t != null) setSheet(() => end = t);
                      },
                      child: Text(end == null ? 'End time' : end!.format(ctx)),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (i) {
                    final wd = i + 1;
                    final on = days.contains(wd);
                    return ChoiceChip(
                      label: Text(_dayLabels[i]),
                      selected: on,
                      onSelected: (v) => setSheet(() {
                        if (v) {
                          days.add(wd);
                        } else {
                          days.remove(wd);
                        }
                      }),
                    );
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: notify,
                  title: const Text('Fire a notification 1 minute before start', style: TextStyle(fontSize: 13)),
                  onChanged: (v) => setSheet(() => notify = v ?? true),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final id = Storage.newId();
                    final subject = {
                      'id': id,
                      'name': name,
                      'color': color,
                      'start': start == null ? '' : _fmt(start!),
                      'end': end == null ? '' : _fmt(end!),
                      'days': days,
                      'notify': notify && start != null,
                    };
                    await Storage.saveSubject(subject);
                    if (subject['notify'] == true) {
                      final oneMinBefore = TimeOfDay(
                        hour: (start!.hour * 60 + start!.minute - 1) ~/ 60 % 24,
                        minute: (start!.minute - 1 + 60) % 60,
                      );
                      await NotificationService.scheduleWeekly(
                        baseId: 'subject-$id',
                        title: '⏳ $name starts in 1 minute',
                        body: '${_fmt(start!)}${end != null ? ' – ${_fmt(end!)}' : ''}',
                        hour: oneMinBefore.hour,
                        minute: oneMinBefore.minute,
                        weekdays: days,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
