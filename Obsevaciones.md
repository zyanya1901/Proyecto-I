**Observaciones sobre la entropía de Shannon en la simulación de las luciérnagas**

**Caso 1:**  
500 luciérnagas, umbral de reseteo de 20, mínimo de luces para resetear de 2, radio de visión de 2 y una ventana de 5\.  
Tarda aproximadamente 1300 ticks hasta que todas estén sincronizadas, notamos que al inicio bajo estas condiciones parecen tener un cierto patrón de prendido y apagado y es por eso que la entropía de Shannon tiene valores muy pequeños, en el momento que todas comienzan a sincronizarse para encenderse, la entropía de Shannon comienza a crecer, esto quiere decir que probablemente resulta que este último proceso tiene un mayor efecto “sorpresa” que el del comienzo.

**Caso 2:**  
500 luciérnagas, umbral de reseteo de 10, mínimo de luces para resetear de 1, radio de visión de 1 y una ventana de 3\.  
Con estas nuevas condiciones parece que las luciérnagas nunca logran sincronizarse para estar todas prendidas, el máximo número de luciérnagas que llega a prenderse en de 180 en 1570 ticks, estos valores permite que exista un patrón que se está constantemente repitiendo, es por eso que la entropía de Shannon no sube sus valores, no es un patrón precisamente difícil de predecir, por lo general, la entropía se mantiene en cero en este caso.

**Caso 3:**  
500 luciérnagas, umbral de reseteo de 35, mínimo de luces para resetear de 4, radio de visión de 4 y una ventana de 7\.  
En este caso, logran estar todas completamente sincronizadas en 342 ticks, el patrón que ahora se ve es espaciado, razón por la cual la entropía de Shannon tiene estos picos de crecimiento cada que ocurre uno de estos eventos “sorpresa” y a medida que comienzan a estar todas en sincronía, la entropía de Shannon baja nuevamente y sus picos no son tan prolongados, esto quiere decir que se vuelve más predecible este patrón.