# 💰 Finances

App per portar el control de les despeses i els ingressos de cada mes, veure'n el
còmput i treure'n estadístiques. Funciona al mòbil com una app normal (PWA).

---

## Provar-la ara mateix

Obre `index.html` amb el navegador. Ja funciona: guarda les dades en aquest
dispositiu. Quan connectis el Google Sheets (pas 2), les tindràs a tot arreu.

---

## Posar-la en marxa

### 1. Publicar-la a internet (GitHub Pages)

1. Crea un repositori nou a GitHub (pot ser **privat**; Pages funciona igual amb
   compte de pagament, o fes-lo públic — l'app no conté cap dada teva).
2. Puja-hi **tots els fitxers menys `Codi_AppsScript.gs`** (el `.gitignore` ja
   l'exclou automàticament).
3. A *Settings → Pages*: **Deploy from a branch** → `main` / `/ (root)`.
4. Al cap d'un minut tindràs una adreça tipus
   `https://elteuusuari.github.io/finances/`.

### 2. Guardar les dades al núvol (Google Sheets)

1. Crea un **Google Sheets** nou i buit.
2. *Extensions → Apps Script*. Esborra el que hi hagi i enganxa-hi el contingut
   de `Codi_AppsScript.gs`.
3. *Implementar → Nova implementació → Aplicació web*:
   - Executar com a: **jo mateix**
   - Qui hi té accés: **qualsevol persona**
   - Copia la **URL** que et dona.
4. Obre `index.html`, busca `WEB_APP_URL: ''` a dalt de tot i enganxa-hi la URL.
5. Torna a pujar `index.html` a GitHub.

> El punt de color de dalt a la dreta et diu com va: **gris** = només aquest
> dispositiu · **verd** = tot desat al núvol · **taronja** = hi ha coses per
> enviar (s'enviaran soles quan tornis a tenir cobertura).

### 3. Instal·lar-la al mòbil

Obre l'adreça amb el Chrome del mòbil → menú **⋮** → *Afegir a la pantalla
d'inici*. Ja la tens com una app, amb icona i tot. Funciona sense connexió.

### 4. (Opcional) Connectar el banc

Amb això els pagaments amb targeta, les compres per internet, els rebuts i la
nòmina s'apunten **sols** cada nit.

1. Dona't d'alta (gratis) a
   [bankaccountdata.gocardless.com](https://bankaccountdata.gocardless.com) →
   *Developers → User secrets*.
2. A l'Apps Script: *Configuració del projecte → Propietats de l'script* → crea
   `GC_SECRET_ID` i `GC_SECRET_KEY` amb les dues claus.
3. Executa, per ordre, aquestes funcions de l'editor d'Apps Script:
   `bancsDisponibles()` → copia l'id del teu banc a la variable `MEU_BANC` →
   `connectarBanc()` → obre l'enllaç que et dona i **identifica't al teu banc** →
   `acabarConnexio()` → `crearTriggerSync()`.

**Sobre la seguretat:** les teves claus del banc no passen mai per l'app ni per
aquest codi. T'identifiques directament a la web del teu banc i el permís que
dones és de **només lectura** — ningú no pot moure ni un cèntim. El pots revocar
quan vulguis des del teu banc.

**Cada 6 mesos** el permís caduca i cal repetir `connectarBanc()` +
`acabarConnexio()`. Amb `estatConnexio()` ho pots comprovar.

---

## Com s'usa

| | |
|---|---|
| **+** (botó verd) | Apuntar una despesa o un ingrés. Import, categoria i llestos. |
| **Tocar un moviment** | Editar-lo o esborrar-lo. |
| **‹ ›** | Moure't entre mesos. |
| **🔍** | Cercar a tot l'històric: «quant m'he gastat mai al Mercadona?» |
| **Mesos** | Comparar com han anat tots els mesos. |
| **Estadístiques** | On se'n va els diners, comparat amb el mes passat. |
| **⚙️** | Categories, pressupostos, objectiu d'estalvi, el que es repeteix cada mes, banc i exportar. |

**Truc per anar de pressa:** quan obris el **+**, sota la descripció hi surten
els últims conceptes que has apuntat. Toca «Mercadona» i ja et posa la
descripció, la categoria i la forma de pagament de cop — només has d'escriure
l'import.

**Pressupostos.** Posa un límit a una categoria (⚙️) i a la portada et sortirà
una barra amb quant en portes gastat.

**Objectiu d'estalvi.** Digues quant vols estalviar cada mes (⚙️) i veuràs si
hi arribes.

**El que es repeteix cada mes.** Lloguer, quotes, la nòmina… posa-ho una vegada
a ⚙️ → *Cada mes igual* i s'apuntarà sol el dia que toqui. Es limita al dia 1-28
perquè funcioni igual també el febrer.

**Per revisar.** Quan el banc et porti moviments, surt un avís groc a la
portada. Allà els confirmes d'un toc. I si un pagament ja l'havies apuntat tu a
mà, l'app **el detecta i t'ofereix fusionar-los** perquè no et quedi duplicat:
es queda l'import i la data del banc, i la descripció i la categoria que havies
posat tu.

---

## Una cosa que no es pot fer

Una app web **no pot llegir la barra de notificacions** del mòbil: Android només
ho permet a les apps natives instal·lades des de la Play Store. Per això la
captura automàtica es fa amb la **connexió del banc**, que a més cobreix les
compres per internet i els ingressos — l'única diferència és que apareixen amb
unes hores de retard en comptes de l'instant.

---

## Fitxers

```
index.html               l'app sencera
sw.js                    perquè funcioni sense connexió
manifest.webmanifest     perquè s'instal·li com una app
img/                     icones
scripts/gen_icons.ps1    regenera les icones
Codi_AppsScript.gs       el backend — NO es puja mai a GitHub
CLAUDE.md                context tècnic per treballar-hi amb Claude Code
```
