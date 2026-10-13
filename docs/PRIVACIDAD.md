# Política de privacidad · Privacy policy

**Dream Racing** · Última actualización: octubre de 2026

> Se publica en `https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html` (GitHub Pages; ver docs/PLAY_STORE.md). El contacto ya está completo; si cambia, volver a correr `python3 tools/play/make_legal_html.py`.

## Español

### Resumen
Para jugar a Dream Racing hace falta **una cuenta con correo electrónico**: tus **créditos, tus autos y tus compras se guardan en nuestro servidor** (así no se pierden si cambiás de teléfono y nadie los puede modificar). El juego no tiene publicidad y no usa análisis (analytics). **No vendemos ni compartimos datos personales.** Tus ajustes, tus tiempos de carrera y el estado de cada auto (pintura, ajuste fino, kilómetros, desgaste) quedan en tu dispositivo.

### Qué datos se guardan y dónde
**En tu dispositivo** (almacenamiento privado de la app):
- Tus **ajustes**, el **nombre de piloto** que elegís, tus **estrellas y tiempos**, y el estado de cada auto (pintura, ajuste fino, kilómetros, desgaste de las gomas). Si desinstalás la app o borrás sus datos, se pierde.
- **Capturas de pantalla** que vos mismo tomás con el botón de captura: se guardan en la carpeta *Imágenes / DreamRacing* de tu teléfono. Podés borrarlas desde la galería del juego o desde tu teléfono.
- **Sensores de movimiento** (acelerómetro/giroscopio): se usan solo para manejar inclinando el teléfono, en el momento, y no se guardan ni se envían.
- **Vibración**: se usa para la respuesta háptica del juego si la activás.

**En nuestro servidor** (Supabase, asociado a tu cuenta; ver «Cuenta, créditos, autos y compras» más abajo): tu correo, tus créditos, qué autos tenés con sus mejoras, gomas y piezas, tus compras de la tienda y un registro técnico de premios y gastos para frenar las trampas.

### Cuenta, créditos, autos y compras (obligatoria)
Para jugar creás una cuenta con tu **correo electrónico** y una **contraseña** (que nunca vemos: se guarda cifrada). El juego le pregunta al servidor cuántos créditos tenés y qué autos tiene tu cuenta, y le manda cada premio y cada compra para que los valide (precio, saldo y topes de premios por hora y por día). Guardamos, asociado a tu cuenta:
- **Correo electrónico** y contraseña cifrada.
- **Créditos** (el dinero del juego) y **autos** con sus mejoras, gomas y piezas compradas.
- **Compras de la tienda**: qué producto compraste y una huella (hash) del comprobante de Google Play; **nunca** tu tarjeta ni tus datos de pago.
- **Registro técnico** de premios y gastos del juego (tipo, referencia, monto y hora): sirve solo para frenar las trampas y se borra solo a los pocos días.
- Fecha del último regalo diario y racha.

Podés jugar **sin conexión** hasta 14 días entre una verificación con el servidor y la siguiente; los cambios que hagas se envían cuando vuelve la conexión. El juego necesita conexión para iniciar sesión, para la primera verificación en cada teléfono, cuando comprás algo y si se detecta un cambio raro en el archivo de progreso (en ese caso el servidor corrige lo que no reconoce).

La cuenta es solo para mayores de 13 años (o con permiso de un adulto). Tu correo **no se muestra a otros jugadores**, no se usa para publicidad ni se comparte con terceros. Podés **cerrar sesión** cuando quieras y **borrar tu cuenta y todo lo que guardamos de ella desde el juego** (*Modo online → Cuenta → Borrar mi cuenta y mis marcas*) o escribiendo al contacto. El borrado es inmediato y definitivo (de la huella de los comprobantes de compra queda solo el código, sin ningún dato tuyo, para que un mismo comprobante no se pueda usar dos veces).

### Conexión a internet
**Versión de Google Play:** el juego completo viene dentro de la app. Se usa internet para iniciar sesión y verificar tu cuenta (créditos, autos y compras), para las compras (a través de Google Play; los datos de pago los maneja Google y nunca llegan a nosotros) y, si participás, para los rankings y el modo online.

**Versión de prueba descargable (APK):** además, la app se conecta a internet para **descargar contenido del juego** (modelos, pistas, música y actualizaciones) desde el repositorio público del proyecto en GitHub (`github.com/webmaletin-art/Rally-Sim-movile`). Al descargar, GitHub puede registrar tu dirección IP como en cualquier descarga web, según su propia política de privacidad. El juego no envía ninguna información tuya en esas descargas.

### Permisos de Android
- `INTERNET` y `ACCESS_NETWORK_STATE`: sirven para iniciar sesión y verificar tu cuenta, para las compras de Google Play y, en la versión de prueba descargable, para descargar el contenido del juego.
- `VIBRATE`: vibración del dispositivo (opcional).
No pedimos acceso a contactos, ubicación, cámara, micrófono ni archivos personales.

### Niños
El juego no contiene publicidad. La cuenta con correo es solo para mayores de 13 años (o con permiso de un adulto). El mundo online incluye un chat entre jugadores con filtro de insultos y botón de reportar (ver más abajo). Las compras dentro del juego (juego completo y bolsas de créditos) se hacen con la cuenta de Google Play de un adulto.

### Compras dentro del juego
Las procesa Google Play Billing. Google puede tratar tus datos de pago y de cuenta según su propia política de privacidad. Para acreditar la compra, nuestro servidor verifica el comprobante con Google: recibe el identificador del producto y el código de la compra, nunca tu tarjeta ni tus datos de pago, y guarda en tu cuenta qué compraste.

### Terceros
No usamos SDK de publicidad, análisis ni redes sociales. Los datos de la cuenta los procesa **Supabase** por nuestra cuenta (proveedor de servicios) y las compras **Google Play**. Los modelos de personajes animados provienen de Mixamo (Adobe) y algunos modelos de escenario de Sweet Home 3D (bibliotecas de uso libre); ver «Créditos» dentro del juego.

### Cambios
Si cambiamos esta política, publicaremos la nueva versión en esta misma dirección y actualizaremos la fecha.

### Contacto
Responsable: SRGamestudios · Correo: **roldanhr98@gmail.com**

---

## English

### Summary
To play Dream Racing you need **an account with an email address**: your **credits, cars and purchases are stored on our server** (so they are not lost if you change phones and nobody can tamper with them). The game has no ads and no analytics. **We do not sell or share personal data.** Your settings, race times and the state of each car (paint, fine tuning, kilometers, wear) stay on your device.

### What is stored and where
**On your device** (the app's private storage):
- Your **settings**, the **driver name** you choose, your **stars and times**, and the state of each car (paint, fine tuning, kilometers, tire wear). Uninstalling the app or clearing its data deletes it.
- **Screenshots** that you take yourself with the capture button are saved in your phone's *Pictures / DreamRacing* folder. You can delete them from the in-game gallery or from your phone.
- **Motion sensors** (accelerometer/gyroscope) are used only to steer by tilting the phone, in real time; they are not stored or transmitted.
- **Vibration** is used for the game's haptic feedback if you turn it on.

**On our server** (Supabase, linked to your account; see "Account, credits, cars and purchases" below): your email, your credits, which cars you have with their upgrades, tires and parts, your store purchases and a technical log of rewards and spending to stop cheating.

### Account, credits, cars and purchases (required)
To play you create an account with your **email address** and a **password** (which we never see: it is stored hashed). The game asks the server how many credits you have and which cars your account has, and sends it every reward and purchase so it can validate them (price, balance and caps on rewards per hour and per day). We store, linked to your account:
- **Email address** and hashed password.
- **Credits** (in-game money) and **cars** with the upgrades, tires and parts you bought.
- **Store purchases**: which product you bought and a hash of the Google Play receipt; **never** your card or payment details.
- A **technical log** of in-game rewards and spending (type, reference, amount and time), used only to stop cheating and automatically deleted after a few days.
- The date of your last daily gift and your streak.

You can play **offline** for up to 14 days between one check with the server and the next; the changes you make are sent when the connection returns. The game needs a connection to sign in, for the first check on each phone, when you buy something and if a strange change is detected in the progress file (in that case the server corrects what it does not recognize).

The account is for people aged 13 or older (or with an adult's permission). Your email is **not shown to other players**, is not used for advertising and is not shared with third parties. You can **sign out** at any time and **delete your account and everything we store about it from the game** (*Online mode → Account → Delete my account and marks*) or by writing to the contact. Deletion is immediate and permanent (of the purchase receipt hashes only the code remains, with no personal data, so that the same receipt cannot be used twice).

### Internet access
**Google Play version:** the full game is inside the app. The internet is used to sign in and verify your account (credits, cars and purchases), for purchases (through Google Play; payment data is handled by Google and never reaches us) and, if you take part, for rankings and the online mode.

**Downloadable test version (APK):** in addition, the app connects to the internet to **download game content** (models, tracks, music and updates) from the project's public GitHub repository (`github.com/webmaletin-art/Rally-Sim-movile`). As with any web download, GitHub may log your IP address under its own privacy policy. The game sends no information about you in these downloads.

### Android permissions
- `INTERNET` and `ACCESS_NETWORK_STATE`: used to sign in and verify your account, for Google Play purchases and, in the downloadable test version, to download game content.
- `VIBRATE`: device vibration (optional).
We do not request contacts, location, camera, microphone or personal files.

### Children
The game has no advertising. The email account is only for people aged 13 or older (or with an adult's permission). The online world includes a player chat with an insult filter and a report button (see below). In-game purchases (full game and credit packs) are made with an adult's Google Play account.

### In-app purchases
They are processed by Google Play Billing. Google may process your payment and account data under its own privacy policy. To credit a purchase, our server verifies the receipt with Google: it receives the product identifier and the purchase code, never your card or payment details, and stores in your account what you bought.

### Third parties
We use no advertising, analytics or social SDKs. Account data is processed by **Supabase** on our behalf (service provider) and purchases by **Google Play**. Animated character models come from Mixamo (Adobe) and some scenery models from Sweet Home 3D (free-to-use libraries); see "Credits" in the game.

### Changes
If this policy changes, the new version will be published at this same address and the date above will be updated.

### Contact
Owner: SRGamestudios · Email: **roldanhr98@gmail.com**

### Rankings online (opcional, solo en las versiones que lo traen)
Si activás «Participar en los rankings online» (viene apagado, aunque tener una cuenta lo activa al crearla y se puede apagar en *Modo online*), el juego envía a nuestro servidor (Supabase) tu **nombre de piloto** y tus **mejores marcas** (tiempo o puntos, pista y auto) para armar el ranking, que ven todos los jugadores. No se envía ningún otro dato, y lo podés apagar cuando quieras. Para borrar tus marcas, borrá tu cuenta desde el juego o escribí al contacto (ver «Eliminar la cuenta y los datos»).

### Mundo online: chat, jugadores cercanos, amigos, reportes y mercado (solo con cuenta)
Si entrás al mundo abierto desde *Modo online*, mientras estás conectado el juego envía a nuestro servidor (Supabase): tu **posición en el mapa del juego, tu velocidad y tu auto** (cada pocos segundos, para mostrar quién está conectado; se borra al salir y el rastro de las últimas posiciones se conserva solo unos minutos), los **mensajes de chat** que escribís (mundial o privados; los insultos se tapan con asteriscos y cada mensaje se guarda), a quién **seguís** (tu lista de amigos) y los autos que **ponés a la venta** en el mercado. **No usamos la ubicación real del teléfono: son coordenadas del mapa del juego.** Si alguien te **reporta**, se guarda una copia de la evidencia (tus mensajes recientes, tus últimas posiciones y velocidades y lo que vio quien reporta) para revisarla a mano; un reporte no castiga a nadie automáticamente. Los mensajes y reportes se conservan para poder revisar abusos; se borran junto con tu cuenta. Los demás jugadores ven tu nombre de piloto, tu auto y tu posición mientras estás conectado.

*(English)* **Online world: chat, nearby players, friends, reports and market (account required):** if you enter the open world from *Online mode*, while connected the game sends to our server (Supabase) your **in-game map position, speed and car** (every few seconds, to show who is online; removed when you leave, and a short trail of recent positions is kept for only a few minutes), the **chat messages** you write (world or private; insults are masked with asterisks and every message is stored), who you **follow** (your friends list) and the cars you **list for sale** on the market. **We do not use the phone's real location: these are map coordinates inside the game.** If someone **reports** you, a copy of the evidence (your recent messages, your latest positions and speeds, and what the reporter saw) is stored to be reviewed by hand; a report never penalizes anyone automatically. Messages and reports are kept to be able to review abuse and are deleted with your account. Other players see your driver name, car and position while you are connected.

### Mundo online: garaje, créditos y tiempo real (solo con cuenta)
En el mundo online tu **billetera de créditos online** y tus **autos online** (con sus mejoras, pintura, gomas y desgaste) viven en nuestro servidor (Supabase) y no en tu teléfono: así nadie puede inventarse plata ni autos. Esos datos son aparte de los de tu cuenta del juego sin conexión (créditos y autos de la cuenta, descritos arriba). Con el **tiempo real** (Supabase Realtime), mientras estás en el mundo online tu auto (posición en el mapa del juego, velocidad, rumbo, modelo y pintura) se envía varias veces por segundo a los jugadores que están cerca para que te vean moverte; **ese tráfico no se guarda**. Las compras con créditos online, los anuncios del mercado y el regalo diario quedan registrados para evitar abusos y se borran junto con tu cuenta.

*(English)* **Online world: garage, credits and real time (account required):** in the online world your **online credits wallet** and your **online cars** (with their upgrades, paint, tyres and wear) live on our server (Supabase), not on your phone, so nobody can invent money or cars. This data is separate from the credits and cars of your regular game account (described above). With **real time** (Supabase Realtime), while you are in the online world your car (in-game map position, speed, heading, model and paint) is sent several times per second to nearby players so they can see you move; **that traffic is not stored**. Purchases with online credits, market listings and the daily gift are logged to prevent abuse and are deleted with your account.

### Dónde se guardan los datos de la cuenta y por cuánto tiempo
Los datos de tu cuenta (correo, créditos, autos, compras, nombre de piloto, marcas y los del modo online) se guardan en servidores de **Supabase**, que los procesa por nuestra cuenta. Los conservamos hasta que borres tu cuenta (desde el juego) o nos pidas borrarla. El registro técnico de premios y gastos se borra solo a los pocos días y los registros técnicos de envíos solo sirven para frenar abusos.

*(English)* **Where account data is stored and for how long:** your account data (email, credits, cars, purchases, driver name, marks and online-mode data) is stored on **Supabase** servers, which process it on our behalf. We keep it until you delete your account (from the game) or ask us to delete it. The technical log of rewards and spending is automatically deleted after a few days, and technical submission logs are only used to stop abuse.

### Eliminar la cuenta y los datos
Instrucciones paso a paso (desde el juego o por correo): `https://webmaletin-art.github.io/Rally-Sim-movile/docs/eliminar-cuenta.html`

*(English)* **Delete your account and data:** step-by-step instructions (from the game or by email): `https://webmaletin-art.github.io/Rally-Sim-movile/docs/eliminar-cuenta.html`

### Tus derechos y el responsable
El responsable es SRGamestudios (Argentina). Podés pedir acceso, corrección o borrado de tus datos escribiendo al contacto, o borrar tu cuenta desde el juego. En Argentina, la Agencia de Acceso a la Información Pública (AAIP), órgano de control de la Ley 25.326, atiende las denuncias y reclamos. Si estás en otro país, también podés ejercer los derechos que te reconozca tu ley local.

*(English)* **Your rights and the controller:** the controller is SRGamestudios (Argentina). You can ask for access, correction or deletion of your data by writing to the contact above, or delete your account from inside the game. In Argentina, the Agency for Access to Public Information (AAIP), the supervisory authority under Law 25,326, handles complaints and claims. If you are in another country (for example the European Union or Brazil), you can also exercise the rights your local law grants you.
