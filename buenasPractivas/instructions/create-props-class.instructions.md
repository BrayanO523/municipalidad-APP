---
applyTo: '**'
---
Esta es una plantilla para crear una clase de propiedades.

La clase props debe contenerse en la carpeta `models` de la característica correspondiente (En caso
de no ser especificada solicitarla o intuirla basada en el archivo contextual seleccionado).

Debe contener un metodo `toJson()` y que debe retornar un `Map<String, dynamic>`.

No uses equatable ni freezed.

Agregar el archivo de las props a los exports del archivo `models.dart` de la característica correspondiente.