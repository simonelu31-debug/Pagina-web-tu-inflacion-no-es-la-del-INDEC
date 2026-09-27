#!/usr/bin/env python3
"""Actualiza los datos del INDEC que usa index.html.

Descarga el Excel de aperturas del IPC (sh_ipc_aperturas.xls), arma para cada
mes desde DESDE las variaciones mensual (m), acumulada en el año (a) e
interanual (y) del nivel general y de los 15 rubros de la calculadora, en las
6 regiones, y reemplaza el bloque de datos de index.html que está entre
/* <datos-indec> */ y /* </datos-indec> */.

Antes de escribir verifica que no falte ninguna serie y que los meses que ya
estaban en la página no cambien (salvo diferencias mínimas de redondeo). Si algo
no cierra, termina con error y no toca nada.

Uso:
    python scripts/actualizar_ipc.py                    # descarga del INDEC
    python scripts/actualizar_ipc.py --archivo X.xls    # usa un Excel local

Lo corre todos los días .github/workflows/actualizar-ipc.yml.
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.request
from decimal import Decimal, ROUND_HALF_UP

import xlrd

URL = "https://www.indec.gob.ar/ftp/cuadros/economia/sh_ipc_aperturas.xls"
DESDE = (2025, 1)  # primer mes que se publica en la página

# Orden de regiones en la página: GBA, Pampeana, Noreste, Noroeste, Cuyo, Patagonia
REGIONES = {"Región GBA": 0, "Región Pampeana": 1, "Región Noreste": 2,
            "Región Noroeste": 3, "Región Cuyo": 4, "Región Patagonia": 5}

# Rubro de la página -> renglón del Excel. El orden define el orden en index.html.
SERIES = {
    "general": "Nivel general",
    "alim": "Alimentos y bebidas no alcohólicas",
    "alq": "Alquiler de la vivienda y gastos conexos",
    "ener": "Electricidad, gas y otros combustibles",
    "tpub": "Transporte público",
    "auto": "Funcionamiento de equipos de transporte personal",
    "prep": "Gastos de prepagas",
    "rem": "Productos medicinales, artefactos y equipos para la salud",
    "com": "Comunicación",
    "rest": "Restaurantes y hoteles",
    "rec": "Recreación y cultura",
    "edu": "Educación",
    "ropa": "Prendas de vestir y calzado",
    "hogar": "Equipamiento y mantenimiento del hogar",
    "cuid": "Bienes y servicios varios",
    "alc": "Bebidas alcohólicas y tabaco",
}

HOJAS = {"m": "Variación mensual aperturas",
         "y": "Var. interanual aperturas",
         "i": "Índices aperturas"}

INICIO, FIN = "/* <datos-indec> */", "/* </datos-indec> */"
TOLERANCIA = 0.15  # puntos: diferencia máxima aceptada con lo que ya estaba publicado

MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
         "agosto", "septiembre", "octubre", "noviembre", "diciembre"]


def descargar(destino):
    req = urllib.request.Request(URL, headers={"User-Agent": "Mozilla/5.0 (tu-inflacion bot)"})
    for intento in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r, open(destino, "wb") as f:
                f.write(r.read())
            return destino
        except Exception as e:  # noqa: BLE001
            print(f"Intento {intento + 1}: no se pudo descargar ({e})", file=sys.stderr)
            time.sleep(2 ** (intento + 1))
    sys.exit("No se pudo descargar el Excel del INDEC.")


def leer_hoja(libro, nombre):
    """Devuelve {(serie, region): {(año, mes): valor}}."""
    hoja = libro.sheet_by_name(nombre)
    datos, region, fechas = {}, None, None
    for r in range(hoja.nrows):
        fila = hoja.row_values(r)
        rotulo = str(fila[0]).strip()
        if rotulo in REGIONES:
            region = REGIONES[rotulo]
            fechas = {}
            for c, v in enumerate(fila[1:], start=1):
                if isinstance(v, float) and v > 0:
                    y, m, *_ = xlrd.xldate_as_tuple(v, libro.datemode)
                    fechas[c] = (y, m)
            continue
        if region is None:
            continue
        for clave, texto in SERIES.items():
            if rotulo == texto and (clave, region) not in datos:
                datos[(clave, region)] = {fechas[c]: float(fila[c]) for c in fechas
                                          if isinstance(fila[c], float)}
    faltan = [(k, r) for k in SERIES for r in range(6) if (k, r) not in datos]
    if faltan:
        sys.exit(f"En la hoja '{nombre}' faltan series: {faltan}")
    return datos


def red(x):
    return float(Decimal(repr(x)).quantize(Decimal("0.1"), rounding=ROUND_HALF_UP))


def armar_meses(libro):
    M, Y, I = (leer_hoja(libro, HOJAS[k]) for k in ("m", "y", "i"))
    disponibles = set.intersection(*(set(s) for h in (M, Y, I) for s in h.values()))
    ultimo = max(disponibles)
    meses = []
    y, m = ultimo
    while (y, m) >= DESDE:
        dic = (y - 1, 12)
        mes = {"year": y, "month": m, "general": None, "data": {}}
        for clave in SERIES:
            fila = {"m": [], "a": [], "y": []}
            for r in range(6):
                if (y, m) not in M[(clave, r)] or (y, m) not in Y[(clave, r)] or dic not in I[(clave, r)]:
                    sys.exit(f"Falta el dato de {clave}, región {r}, {MESES[m - 1]} {y}.")
                fila["m"].append(red(M[(clave, r)][(y, m)]))
                fila["y"].append(red(Y[(clave, r)][(y, m)]))
                fila["a"].append(red((I[(clave, r)][(y, m)] / I[(clave, r)][dic] - 1) * 100))
            if clave == "general":
                mes["general"] = fila
            else:
                mes["data"][clave] = fila
        meses.append(mes)
        y, m = (y - 1, 12) if m == 1 else (y, m - 1)
    return meses


def bloque_js(meses):
    lineas = []
    for M in meses:
        filas = [f'  {{"year":{M["year"]},"month":{M["month"]},',
                 f'   "general":{json.dumps(M["general"], separators=(",", ":"))},',
                 '   "data":{']
        filas.append(",\n".join(f'    "{k}":{json.dumps(v, separators=(",", ":"))}' for k, v in M["data"].items()))
        filas.append("  }}")
        lineas.append("\n".join(filas))
    return (f"{INICIO}\n// Generado por scripts/actualizar_ipc.py a partir del Excel de aperturas del INDEC. No editar a mano.\n"
            "const MONTHS = [\n" + ",\n".join(lineas) + "\n];\n" + FIN)


def meses_actuales(html):
    """Lee los meses que ya están publicados (si el bloque está en formato JSON)."""
    i, f = html.find(INICIO), html.find(FIN)
    if i < 0 or f < 0:
        sys.exit("No encontré las marcas de datos en index.html.")
    cuerpo = html[i:f]
    j = cuerpo.find("const MONTHS = ")
    try:
        return json.loads(cuerpo[j + len("const MONTHS = "):cuerpo.rindex("];") + 1])
    except ValueError:
        return None


def comparar(viejos, nuevos):
    por_mes = {(M["year"], M["month"]): M for M in nuevos}
    problemas = []
    for V in viejos:
        N = por_mes.get((V["year"], V["month"]))
        if not N:
            problemas.append(f"{MESES[V['month'] - 1]} {V['year']} ya no está en el Excel")
            continue
        pares = [("general", V["general"], N["general"])] + [(k, V["data"][k], N["data"].get(k)) for k in V["data"]]
        for k, a, b in pares:
            for p in "may":
                for r in range(6):
                    if b is None or abs(a[p][r] - b[p][r]) > TOLERANCIA:
                        problemas.append(f"{MESES[V['month'] - 1]} {V['year']} {k} {p} región {r}: "
                                         f"{a[p][r]} -> {b[p][r] if b else '?'}")
    return problemas


def salida(clave, valor):
    ruta = os.environ.get("GITHUB_OUTPUT")
    if ruta:
        with open(ruta, "a", encoding="utf-8") as f:
            f.write(f"{clave}={valor}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--archivo", help="Excel local en lugar de descargarlo")
    ap.add_argument("--html", default="index.html")
    ap.add_argument("--forzar", action="store_true", help="escribir aunque cambien meses ya publicados")
    args = ap.parse_args()

    archivo = args.archivo or descargar("sh_ipc_aperturas.xls")
    nuevos = armar_meses(xlrd.open_workbook(archivo))

    html = open(args.html, encoding="utf-8").read()
    viejos = meses_actuales(html)
    if viejos:
        problemas = comparar(viejos, nuevos)
        if problemas and not args.forzar:
            print("Los datos nuevos no coinciden con los ya publicados; no se actualiza:", file=sys.stderr)
            print("\n".join(problemas[:30]), file=sys.stderr)
            sys.exit(1)
    ya = {(M["year"], M["month"]) for M in (viejos or [])}
    agregados = [f"{MESES[M['month'] - 1]} {M['year']}" for M in nuevos if (M["year"], M["month"]) not in ya]

    i, f = html.find(INICIO), html.find(FIN) + len(FIN)
    nuevo_html = html[:i] + bloque_js(nuevos) + html[f:]
    if nuevo_html == html:
        print("Sin cambios: la página ya tiene el último dato del INDEC.")
        salida("cambios", "no")
        return
    open(args.html, "w", encoding="utf-8").write(nuevo_html)
    ultimo = nuevos[0]
    msg = (f"Datos del INDEC: {', '.join(agregados)}" if agregados and viejos
           else f"Datos del INDEC actualizados hasta {MESES[ultimo['month'] - 1]} {ultimo['year']}")
    print(msg)
    salida("cambios", "si")
    salida("mensaje", msg)


if __name__ == "__main__":
    main()
