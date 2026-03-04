---
applyTo: '**'
---
Provide project context and coding guidelines that AI should follow when generating code, answering questions, or reviewing changes.

-- Reglas de implementación de UI:
   1. Al separar o refactorizar código de la interfaz de usuario, EVITA crear métodos auxiliares (helper methods) que retornen Widgets (ej: `Widget _buildTitle() { ... }`).
   2. EN SU LUGAR, crea siempre nuevos Widgets separados (clases que extiendan `StatelessWidget` o `StatefulWidget`).
   3. Esto es obligatorio para garantizar la optimización de reconstrucciones (rebuilds) y el uso correcto de constructores `const`.