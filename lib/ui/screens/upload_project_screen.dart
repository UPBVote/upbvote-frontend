import 'package:flutter/material.dart';

class UploadProjectScreen extends StatelessWidget {
  const UploadProjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Proyecto")),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Título del Proyecto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Materia Asociada',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text("Adjuntar Documentos/Videos"),
              onPressed: () {},
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("CREAR PROYECTO"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
