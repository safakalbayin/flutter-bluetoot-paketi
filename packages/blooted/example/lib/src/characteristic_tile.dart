import 'package:blooted/blooted.dart';
import 'package:flutter/material.dart';

import 'ble_controller.dart';

class CharacteristicTile extends StatefulWidget {
  const CharacteristicTile({
    super.key,
    required this.controller,
    required this.serviceUuid,
    required this.characteristic,
  });

  final BleController controller;
  final String serviceUuid;
  final BleCharacteristic characteristic;

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  final input = TextEditingController();

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final characteristic = widget.characteristic;
    final uuid = characteristic.uuid;
    final service = widget.serviceUuid;
    final key = c.targetKey(service, uuid);
    final value = c.values[key];
    final canWrite = characteristic.canWrite || characteristic.canWriteWithoutResponse;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(uuid, style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 6),
          Text([
            if (characteristic.canRead) 'READ',
            if (characteristic.canWrite) 'WRITE',
            if (characteristic.canWriteWithoutResponse) 'WRITE NO RESPONSE',
            if (characteristic.canNotify) 'NOTIFY',
            if (characteristic.canIndicate) 'INDICATE',
          ].join(' · ')),
          if (value != null)
            SelectableText('Değer: ${BleController.hex(value)}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (characteristic.canRead)
                OutlinedButton(
                  onPressed: c.busy ? null : () => c.read(service, uuid),
                  child: const Text('Oku'),
                ),
              if (characteristic.canNotify || characteristic.canIndicate)
                OutlinedButton(
                  onPressed: c.busy ? null : () => c.toggleNotify(service, uuid),
                  child: Text(c.notifying.contains(key) ? 'Bildirimi kapat' : 'Bildirimi aç'),
                ),
            ],
          ),
          if (canWrite) ...[
            const SizedBox(height: 8),
            TextField(
              controller: input,
              enabled: !c.busy,
              maxLength: 59,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Hex veri · en fazla 20 bayt',
                hintText: '01 A0 FF',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: c.busy ? null : () => c.write(
                  service, uuid, input.text, characteristic.canWrite,
                ),
                child: Text(characteristic.canWrite ? 'Gönder · yanıtlı' : 'Gönder · yanıtsız'),
              ),
            ),
          ],
          const Divider(),
        ],
      ),
    );
  }
}
