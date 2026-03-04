---
applyTo: **/*.*
description: Este archivo ofrece lineamientos para seguir buenas practicas de codigo en el proyecto.
---

A. Seguir los principios SOLID

B. El codigo debe evitar crear connascence fuerte entre los modulos, promoviendo la independencia y facilitando el mantenimiento. En caso de que un artefacto dependa de otro inevitablemente, se debe buscar minimizar la connascence entre ellos moviendose a connascence estáticas lo mayor que se pueda.

C. Se debe evitar lo mayor que se pueda crear instancias de clases internamente sobre otras clases. Se debe buscar siempre la inyección de dependencias y asi evitar el acomplamiento fuerte entre clases.

D. Nombrar metodos, clases y variables que sean autodescriptivos y eviten lo mas que se pueda el tener que comentarlos para entender su proposito (meaning connascense)