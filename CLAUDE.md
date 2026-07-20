# Finances — context del projecte (per a Claude Code)

> Llegeix aquest fitxer sencer abans de tocar res. **Tota la interfície i les
> converses són en català.**

## 1. Què és
PWA personal d'en Pol per portar el control de les seves finances: apuntar
**despeses** i **ingressos**, veure el **còmput del mes** i treure'n
**estadístiques** i **comparatives entre mesos**.

**Prioritats de disseny (per ordre):**
1. **Apuntar una despesa ha de ser instantani** — si costa, no s'usarà.
2. Que el resum del mes s'entengui d'un cop d'ull.
3. Com més coses s'apuntin **soles** (banc), millor.

## 2. Arquitectura i stack
Idèntica al projecte *Coordinació 2n* (mateix patró provat):
- **Frontend:** un únic `index.html` (HTML + CSS + JS, **sense frameworks**,
  sense build). Es serveix per **GitHub Pages**.
- **Backend:** **Google Apps Script** (Web App) + **Google Sheets**. Tot l'estat
  es desa com un **blob JSON** a la pestanya `DB` (partit en trossos de 45.000
  caràcters). Escriptures serialitzades amb **`LockService`**.
- **PWA:** `manifest.webmanifest` + `sw.js` + icones a `img/`.

Config al principi de `index.html` (objecte `CONFIG`):
- `WEB_APP_URL` → URL del desplegament d'Apps Script. **Si és buit, `LOCAL_ONLY`
  = cert** i l'app funciona només amb localStorage (útil per provar).
- `STORE_KEY = 'finances_v1'`, `PEND_KEY = 'finances_pending_v1'`,
  `PIN_KEY = 'finances_pin_v1'`.

## 2b. PIN (per què hi és)
El repositori és **públic**, o sigui que la `WEB_APP_URL` és visible per a
qualsevol. Sense cap comprovació, qui la trobés podria **llegir i escriure**
totes les finances. Per això:
- El backend compara el que envia l'app amb la propietat de l'script **`PIN`**.
  Si la propietat **no existeix, el backend queda obert** (només per provar).
- **El PIN no és MAI al codi ni a cap fitxer del repositori.** L'usuari
  l'escriu un cop per dispositiu i es desa a `localStorage`, i des d'aleshores
  viatja al camp `secret` de cada petició.
- `mostraPin()` pinta la pantalla de bloqueig (teclat propi, també funciona amb
  el teclat físic). `provaPin()` el valida **contra el servidor** amb un
  `getState` abans de desar-lo — així no es desa mai un PIN dolent.
- Si el servidor respon `{error:'pin'}` (`PinError`), `pull()` i `flushPending()`
  esborren el PIN i tornen a demanar-lo. ⚠️ **La cua `PENDING` no es toca**:
  els canvis pendents es reenvien quan torni a entrar.
- `flushPending()` i `pull()` no fan res si no hi ha PIN, per no cremar
  peticions mentre la pantalla de bloqueig és a la vista.

## 3. Fitxers del repositori
```
index.html               ← tot el frontend (l'app)
sw.js                    ← service worker (network-first per a l'HTML)
manifest.webmanifest     ← PWA
.nojekyll                ← perquè GitHub Pages no "processi" res
img/                     ← favicon.svg + icon-192/512/maskable.png
scripts/gen_icons.ps1    ← regenera els PNG de les icones
Codi_AppsScript.gs       ← BACKEND. NO va MAI a GitHub (veure §8). Local + Apps Script.
CLAUDE.md                ← aquest fitxer
README.md                ← instruccions d'ús per a l'usuari
.gitignore               ← exclou Codi_AppsScript.gs
```

## 4. Model de dades (`STATE`)
```
tx[]        // moviments — l'única taula que importa
cats[]      // categories {id, n:nom, e:emoji, k:'d'|'i', col:color}
recur[]     // moviments mensuals automàtics
budgets{}   // {catId: límit mensual en €}
settings{}  // {cur:'€', goal:objectiu d'estalvi mensual}
bank{}      // estat de la connexió PSD2 {reqId, institution, accounts[], connected}
```
Un moviment (`tx`):
```
{ id, date:'YYYY-MM-DD', type:'d'|'i', amount:>0, cat, desc, method,
  src:'manual'|'banc', bankId, pend:bool, note, ok:bool, createdAt }
```
Un recurrent (`recur`):
```
{ id, type, amount, cat, desc, method, day:1-28, actiu:bool, lastYm:'YYYY-MM' }
```
- **`amount` sempre positiu**; el signe el dona `type`. No hi ha imports negatius
  enlloc del model — si algun dia n'entra un, `normalize()` l'arregla amb `Math.abs`.
- **`bankId`** és la clau de deduplicació dels moviments importats del banc.
  Si `bankId` ja existeix a `STATE.tx`, la sincronització l'ignora.
- **`pend`** = moviment encara no consolidat pel banc (surt amb l'etiqueta groga
  "pendent").
- **`ok`** = l'usuari ja l'ha validat. Els **manuals neixen `ok:true`**; els del
  **banc neixen `ok:false`** i van a la safata «Per revisar».
- `method` ∈ `targeta | efectiu | online | transf | domic` (constant `METHODS`).
- Categories per defecte a `CATS_DEF`; `k:'d'` despeses, `k:'i'` ingressos.
- `day` dels recurrents està **limitat a 28** perquè funcioni igual tots els
  mesos (també el febrer). `lastYm` evita que es generin dues vegades.

`normalize()` garanteix que totes les claus existeixen i sanejat de cada `tx`.

## 4b. Duplicats banc ↔ manual (secció 2b del codi)
El problema real: apuntes un pagament a mà i tres dies després el banc te'l porta
altre cop. La solució viu **al frontend**, no al backend:
- `possibleDuplicat(t)` — per a un moviment del **banc**, busca un **manual** amb
  el mateix signe, **import idèntic** (±0,005 €) i **data a ≤ 4 dies**. Retorna el
  més pròxim en el temps, o `null`.
- `fusionar(bancId, manualId)` — **es queda el del banc** (import i data són els
  fiables) però **hereta el que havies escrit tu** (descripció, categoria, nota i
  el mètode si no era el genèric `targeta`), esborra el manual i marca `ok:true`.
- La safata `sheetRevisar()` mostra cada moviment del banc amb dues sortides:
  *«És el mateix»* (fusiona) o *«Són diferents»* (només marca `ok`). Si no hi ha
  cap candidat a duplicat, les opcions són *«Està bé»* / *«Canviar categoria»*.
- ⚠️ La finestra de 4 dies és deliberada. Si s'amplia massa, dues compres iguals
  al mateix comerç en dies diferents es marcarien com a duplicades.

## 5. Vistes (variable `VIEW`)
- **`home`** — mes seleccionat (`MONTH`, format `'YYYY-MM'`): balanç, ingressos vs
  despeses, ritme de despesa i projecció de final de mes, **objectiu d'estalvi**,
  **avís de la safata de revisió**, pressupostos amb barra, i moviments
  **agrupats per dia** amb subtotal diari.
- **`mesos`** — barres dels últims 12 mesos (ingressos i despeses de costat),
  llista de tots els mesos amb balanç, i acumulats des de l'inici.
- **`estad`** — del mes seleccionat: **donut** per categoria, comparativa amb el
  mes anterior, desglossament per mètode de pagament, top 5 despeses i xifres.

`MONTH` és compartida entre `home` i `estad`; no es pot navegar a mesos futurs.

**Fulls (sheets)** — tots passen per `openSheet()` / `closeSheet()`:
`sheetTx` (afegir/editar, amb **suggeriments** del que ja has apuntat: omplen
descripció + categoria + mètode d'un toc), `sheetRevisar`, `sheetCats` +
`sheetCatEdit`, `sheetRecur` + `sheetRecEdit`, `sheetCerca` (cerca a tot
l'històric amb totals i mitjana mensual), `sheetCfg`, `sheetBank`.

## 6. Sincronització i fiabilitat (mateix patró que Coordinació 2n)
- **Optimista:** les mutacions toquen `STATE` i criden `persist(action,payload)`,
  que desa a localStorage a l'instant i encua la crida al núvol.
- **`request()`** → POST a `WEB_APP_URL` amb **timeout de 15 s** (AbortController).
- **Cua `PENDING`** a localStorage: si falla la xarxa, es reintenta a
  `flushPending()` (abans de cada pull, en tornar el focus i a l'event `online`).
  **Cap moviment es perd.**
- **`pull()`** cada 30 s (només amb la pestanya visible i a `home`). Compara
  signatura JSON (`_lastSig`) i **no re-renderitza si no hi ha canvis**. Si hi ha
  `PENDING` sense enviar, **no** sobreescriu l'estat local.
- **Backend idempotent:** totes les altes són upsert per `id` → un reintent mai
  duplica un moviment.
- El **punt de color** de la barra superior indica l'estat: gris (local),
  verd (sincronitzat), taronja (hi ha coses pendents d'enviar).

## 7. Connexió bancària PSD2 (Fase 2)
Viu **sencera al backend** (`Codi_AppsScript.gs`, §4 del fitxer). Proveïdor:
**Enable Banking** (`https://api.enablebanking.com`), nivell gratuït
«Restricted Production» per als comptes propis de l'usuari.

> ❌ **GoCardless Bank Account Data (Nordigen) ja no serveix.** Està tancat a
> altes noves i en procés de tancament (comprovat el juliol de 2026). Si algú
> hi entra, l'únic camí obert és el producte de *cobrament* per domiciliació,
> amb comissió per transacció, que no té res a veure. No hi tornis.

- **Autenticació:** JWT **RS256** signat amb la clau privada de l'aplicació.
  Header `{typ:'JWT', alg:'RS256', kid:<app id>}`, cos
  `{iss:'enablebanking.com', aud:'api.enablebanking.com', iat, exp}`, màxim 24 h.
  A Apps Script se signa amb `Utilities.computeRsaSha256Signature()` i es
  codifica amb `Utilities.base64EncodeWebSafe()` sense els `=` finals
  (`_b64url`). El JWT es cacheja 55 min a `CacheService`.
- Les propietats (`EB_APP_ID`, `EB_PRIVATE_KEY`, `EB_REDIRECT`) van a
  **Propietats de l'script**, MAI al codi ni a cap fitxer del disc.
- **`redirect_url` = la URL del propi Web App.** `doGet(e)` detecta el
  `?code=…` del retorn i crida `ebCrearSessio(code)` → així la connexió es tanca
  sola sense haver de copiar cap codi a mà.
- Flux d'alta, un sol cop: `provaConnexio()` → `bancsDisponibles()` → omplir
  `MEU_BANC` amb el **nom exacte** → `connectarBanc()` (l'usuari s'identifica
  **al seu banc**) → `crearTriggerSync()`.
- `sincronitzarBanc()` corre cada dia a les 6:00. Primera passada 90 dies
  enrere, després només 10. Pagina amb `continuation_key` (límit de 20 voltes).
  Dedupa per `bankId` (`entry_reference` → `transaction_id` → composada).

### Classificació (§5 del backend) — llegir abans de tocar-hi
Ordre de decisió, del més fiable al menys:
1. **Traspassos** (Trade Republic i altres comptes propis) i **Bizum**: manen
   sobre tota la resta, siguin quins siguin els altres senyals.
2. **`merchant_category_code` (MCC)** — el codi ISO 18245 del tipus de negoci.
   És el senyal **més fiable** per a compres amb targeta: no depèn de com
   s'escrigui el nom del comerç. Taula al mapa `MCC`.
3. **Paraules clau** (`REGLES`), la primera que coincideix guanya.

⚠️ **L'error que va tenir la primera versió i que no s'ha de repetir:** es
classificava **només amb `remittance_information`**. Els bancs hi posen sovint
un text genèric (`COMPRA TARJETA 000123`) i deixen el nom del comerç a
**`creditor.name`**. Resultat: mig Mercadona i mig restaurant anaven a «Altres».
Ara `_ebTextMatch(b)` **ajunta tots els camps** (nom, concepte, codi del banc,
informació addicional) i és això el que es fa servir per classificar.
Separació de responsabilitats:
- `_ebNom(b)` → qui cobra/paga · `_ebConcepte(b)` → el text lliure
- `_ebDesc(b)` → el que **es MOSTRA** (mana el nom del comerç: s'entén millor)
- `_ebTextMatch(b)` → el que es fa servir per **CLASSIFICAR** (tot junt)

Eines de manteniment: `resumImportacio()` (comptadors, no ensenya dades),
`elsQueNoSap()` (els conceptes que no ha sabut classificar, per ampliar
`REGLES`) i `recategoritzaTot()` (torna a passar les regles pels que ja hi ha;
només amb el text desat, perquè l'MCC no el guardem al moviment).
- **Mapatge de camps** (Enable Banking segueix Berlin Group):
  `credit_debit_indicator` `'CRDT'`=ingrés / `'DBIT'`=despesa ·
  `transaction_amount.amount` és un **string positiu** · `status!=='BOOK'` →
  `pend:true` · descripció des de `remittance_information` (**array**), i si no
  `creditor.name`/`debtor.name` (funció `_ebDesc`).
- **El permís caduca** (`DIES_ACCES = 90`). `estatConnexio()` ho comprova; quan
  caduqui cal repetir `connectarBanc()`.
- **Mai demanem ni guardem credencials del banc.** L'usuari s'autentica a la web
  del seu banc i el permís concedit és de **només lectura**.
- ⚠️ **No provat contra un banc real.** El codi segueix la documentació oficial,
  però fins que no hi hagi una alta real no es pot garantir que CaixaBank
  ompli els camps tal com s'espera. El primer dia caldrà mirar el registre
  d'execució i ajustar `_ebDesc`, `endevinaMetode` i `REGLES`.

⚠️ **Límit conegut i important:** una PWA **no pot llegir la barra de
notificacions d'Android** — no existeix cap API web que ho permeti. La
sincronització bancària és el substitut (cobreix targeta, internet i ingressos,
amb unes hores de retard en comptes de temps real). Si algun dia es vol la
captura instantània, cal una **app Android nativa** amb
`NotificationListenerService` que faci POST a aquest mateix Apps Script.

## 8. Desplegament
Dos destins separats:
1. **Web → GitHub Pages:** puja `index.html`, `sw.js`, `manifest.webmanifest`,
   `.nojekyll`, `img/` i `scripts/`. **MAI `Codi_AppsScript.gs`.**
   GitHub Pages: *Deploy from a branch* → `main` / root.
2. **Backend → Apps Script:** enganxa `Codi_AppsScript.gs` a l'editor. Si has
   canviat **casos del `switch` de `_handle`** → cal **nou desplegament del Web
   App** (Implementar → Gestionar implementacions → versió nova).

**Memòria cau:** el `sw.js` és network-first per a l'HTML, així que els canvis
arriben sols. Si es fa el ruc, obre amb `?v=N`.

## 9. Convencions i flux de treball
- **Idioma:** tot en **català** (UI, missatges, comentaris de cara a l'usuari).
- **Sense frameworks**, sense build. Un sol `index.html`.
- Import sempre en **positiu** al model; formatat amb `eur(n, sign)`.
- Els noms de mes es capitalitzen amb `cap1()`, **mai** amb `text-transform:
  capitalize` (posava "Juliol De 2026").
- **Validació obligatòria a cada canvi:**
  ```bash
  node -e "const fs=require('fs');const h=fs.readFileSync('index.html','utf8');
  fs.writeFileSync(process.env.TEMP+'/app_check.js',
  [...h.matchAll(/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n;\n'))"
  node --check "$TEMP/app_check.js"
  cp Codi_AppsScript.gs "$TEMP/chk.js" && node --check "$TEMP/chk.js"
  ```

## 10. Pendent / idees ja parlades
- **Fase 2:** activar la connexió PSD2 (falta que en Pol es doni d'alta a
  **Enable Banking**, generi la clau i ompli les tres propietats de l'script).
  Tot el codi hi és; el primer dia caldrà ajustar les regles amb dades reals.
- **Importar un CSV/Excel del banc** per omplir l'històric d'abans de l'app.
- **Etiquetes** transversals (ex.: «viatge a Roma») que travessin categories.
- **Gràfic d'evolució per categoria** (com ha crescut «Restaurants» en 6 mesos).
- Si mai es vol la captura instantània de notificacions → app Android nativa
  que faci POST a l'Apps Script (§7).

**Ja fet** (no ho tornis a proposar): safata de revisió, deduplicació banc↔manual,
categories editables, recurrents mensuals, objectiu d'estalvi, cerca global,
suggeriments a l'entrada ràpida, exportació CSV/JSON.
