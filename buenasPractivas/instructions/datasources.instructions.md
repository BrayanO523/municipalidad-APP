---
applyTo: '**/datasources/**'
description: Este archivo ofrece lineamientos para seguir buenas practicas en la creacion de datasources en el proyecto.
---
 
A. Los datasources deben ser creados en la carpeta `datasources` dentro del proyecto.
B. Cada datasource debe tener un nombre descriptivo que refleje su función o el tipo de datos que maneja.

# Dasources con llamadas a APIs
Deben incluir al menos los siquientes requerimientos:
- Incluir la variable url de tipo string que contenga la URL base de la API a la que se conectará el datasource, usualmente esta se obtiene llamando a `ApiEndpoints`.
- Incluir la variable `_apiRequestHelper` de tipo `ApiRequestHelper`. Esta variable se utilizará para realizar las solicitudes a la API de manera eficiente y consistente por los métodos del datasource
- Incluir un constructor que inicialice la variable `_apiRequestHelper` con una instancia de `ApiRequestHelper` (Inyectada). Esto asegurará que el datasource esté listo para realizar solicitudes a la API desde el momento en que se cree.
- Implementar métodos específicos para cada operación que el datasource necesite realizar, utilizando la variable `_apiRequestHelper` para hacer las solicitudes a la API. Esto permitirá una mejor organización y reutilización del código dentro del datasource.
- Deben retornar un either de la siguiente forma: `Future<Either<ErrorItem, Map<String, dynamic>>> traerBodegas()` donde `ErrorItem` es un objeto que contiene información sobre el error ocurrido, y `Map<String, dynamic>` es el resultado exitoso de la operación realizada por el datasource (Si el endpoint solo retorna una lista debe ser `List<dynamic>` en lugar de `Map<String, dynamic>`). Esto permitirá manejar de manera efectiva tanto los casos de éxito como los de error en las operaciones del datasource. El repositorio se encargara de mapear el resultado al modelo correspondiente.
- Ordena los métodos del datasource basado en el acronimo CRUD (Create, Read, Update, Delete) para mejorar la legibilidad y organización del código. Esto facilitará la navegación y comprensión de los métodos dentro del datasource, permitiendo a los desarrolladores identificar rápidamente las operaciones disponibles y su propósito.