---
applyTo: '**'
---
Esta instruccion es para saber como crear una entidad y su modelo en el proyecto a partir de un objeto json.

Para crear la entidad y el modelo se debe realizar los siguientes pasos:

1. consultar la feature en la que se va a trabajar o intuirlo por el archivo contextual seleccionado y ver cual es la feature en que reside.

2. Proporcionar el objeto JSON que se va a utilizar para crear la entidad y el modelo.

```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john.doe@example.com"
}
```

3. Proporcionar el nombre de la entidad.
El nombre del modelo siempre irá seguido de Json, por ejemplo si la entidad se llama User, el modelo se llamará UserJson.

4. Crear la entidad:
Consultar primero el nombre de la entidad y ver si ya existe la entidad, si no existe se debe crear en la capa de dominio de la feature.

Todos los atributos de la entidad pueden ser nullables (al menos que sea unas props).

Para los datos que son de tipo fecha usar DateTime?.
Para los datos que son double usar num?.
Cuando un dato sea de tipo numerico e inicie con id se debe usar int?, caso contrario usar num?.
Cuando un campo se llama active, activa, isActive, is_active, enabled, enable, se debe usar bool?.
No es necesario Castear los tipos de datos, solo asignarlos directamente.

5. Crear el modelo:
Una vez creada la entidad, se debe crear el modelo correspondiente. El modelo debe incluir la lógica para convertir el objeto JSON en una instancia de la entidad y viceversa. Debe contener los métodos fromJson, toJson y fromEntity. Debe estar contenida en la capa de datos de la feature. El modelo debe extender de la entidad. No debe contener lógica de negocio, solo la lógica de conversión. No debe tener variables internas se deben usar las variables de la entidad usando super en el constructor.

El modelo puede tener tambien funciones de alto nivel para desserealizar una lista de objetos json a una lista de entidades y viceversa. por ejemplo asi:

```dart
List<ErrorApiData> errorApiDataListFromJson(String str) =>
    List<ErrorApiData>.from(
        json.decode(str).map((x) => ErrorApiData.fromJson(x)));
String errorApiDataListToJson(List<ErrorApiData> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));
```

El nombre del archivo del modelo se debe llamar igual que la entidad pero agregando _model al final, por ejemplo si la entidad se llama User, el archivo del modelo se llamará user_model.dart.

Inyecta los datos en el constructor del modelo usando super.

En el fromJson no inicialices los atributos con valores por defecto, solo asignalos directamente aun si son nulos.
```dart 
const FincaJson({
    super.idFinca,
    super.idPerfil,
    super.codFinca,
    super.nombreFinca,
    super.direccion,
    super.activa,
  });
```

6. Actualizar los archivos de barril de la feature:
Actualizar los archivos ```dart models.dart``` y ```dart entities.dart``` en las carpetas correspondientes para exportar la nueva entidad y el nuevo modelo.