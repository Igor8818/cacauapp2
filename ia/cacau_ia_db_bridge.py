#!/usr/bin/env python3
"""
Ponte CLI de Integracao IA (Visao Computacional) <-> SQL Server (CacauAppBD).

Atende as regras do projeto:
- Zero SaaS, site ou aplicacao web (execucao puramente local em linha de comando).
- Respeita estritamente RBAC (GRANT/DENY), Dynamic Data Masking (DDM) e
  Row-Level Security (RLS) usando EXECUTE AS USER sob o perfil solicitante.
- Registra toda tentativa (permitida, negada ou bloqueada) em dbo.Auditoria_Log.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image

try:
    import ai_edge_litert.interpreter as tflite_runtime
except ImportError:
    tflite_runtime = None

ROOT_DIR = Path(__file__).resolve().parent.parent
DEFAULT_SQLCMD = "/mnt/c/Program Files/Microsoft SQL Server/Client SDK/ODBC/180/Tools/Binn/SQLCMD.EXE"
DEFAULT_TFLITE = ROOT_DIR / "app" / "src" / "main" / "assets" / "detector.tflite"

# Allowlist estrita de perfis e papeis do banco CacauAppBD
ALLOWED_PROFILES: dict[str, str] = {
    "usr_tecnico1": "Tecnico_Campo",
    "usr_tecnico2": "Tecnico_Campo",
    "usr_auditor1": "Auditor_Agronomo",
    "usr_admin1": "Admin_Sistema",
    "usr_app_ia": "Role_App_IA",
}

SQLI_PATTERNS = [
    re.compile(r"('|\")\s*or\s+1\s*=\s*1", re.IGNORECASE),
    re.compile(r";\s*(drop|delete|truncate|alter|exec|xp_cmdshell)\b", re.IGNORECASE),
    re.compile(r"\bunion\s+select\b", re.IGNORECASE),
    re.compile(r"--|/\*|\*/"),
]


@dataclass
class DetectionResult:
    boxes: list[list[float]]
    latency_ms: float
    mean_luminance: float
    used_gamma_lut: bool
    config_version: str


def _resolve_sqlcmd() -> str:
    env_path = os.getenv("SQLCMD_PATH")
    if env_path and Path(env_path).exists():
        return env_path
    if Path(DEFAULT_SQLCMD).exists():
        return DEFAULT_SQLCMD
    return "sqlcmd"


def _sql_escape(value: str) -> str:
    return value.replace("'", "''")[:290]


def _to_windows_path(path: Path | str) -> str:
    s = str(path)
    if s.startswith("/mnt/") and len(s) > 6:
        drive = s[5].upper()
        return f"{drive}:{s[6:].replace('/', chr(92))}"
    return s


def _decode_sqlcmd_bytes(data: bytes) -> str:
    if not data:
        return ""
    for enc in ("utf-8", "cp1252", "latin-1"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def run_sql_raw(sql_text: str, database: str = "CacauAppBD") -> tuple[int, str]:
    """Executa lote T-SQL no SQL Server local via arquivo temporario UTF-8 (evita escaping CLI)."""
    sqlcmd = _resolve_sqlcmd()
    host = os.getenv("SQLSERVER_HOST", "localhost")
    tmp_dir = ROOT_DIR / "ia" / ".tmp_sql"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".sql", dir=tmp_dir, delete=False, encoding="utf-8") as tf:
        tf.write(sql_text)
        tf_path = Path(tf.name)
    try:
        win_sql = _to_windows_path(tf_path)
        cmd = [sqlcmd, "-S", host, "-E", "-C", "-W", "-f", "65001", "-d", database, "-i", win_sql]
        proc = subprocess.run(cmd, capture_output=True)
        out = _decode_sqlcmd_bytes(proc.stdout)
        err = _decode_sqlcmd_bytes(proc.stderr)
        combined = out + ("\n" + err if err else "")
        return proc.returncode, combined.strip()
    finally:
        tf_path.unlink(missing_ok=True)


def load_pipeline_config(version: str = "v2") -> dict[str, Any]:
    cfg_path = ROOT_DIR / "ia" / "configs" / f"pipeline_{version}.json"
    if not cfg_path.exists():
        raise FileNotFoundError(f"Configuracao nao encontrada: {cfg_path}")
    return json.loads(cfg_path.read_text(encoding="utf-8"))


def run_tflite_inference(
    image_path: str | Path,
    model_path: str | Path = DEFAULT_TFLITE,
    config_version: str = "v2",
) -> DetectionResult:
    """Executa inferencia YOLOv8/TFLite espelhando o pipeline do app Android."""
    if tflite_runtime is None:
        raise RuntimeError("ai_edge_litert nao disponivel neste ambiente Python.")

    cfg = load_pipeline_config(config_version)
    prep = cfg["preprocessing"]
    inf = cfg["inference"]
    post = cfg["postprocessing"]

    input_size = int(prep["input_size"])
    conf_thresh = float(inf["score_threshold"])
    max_results = int(inf["max_results"])
    iou_thresh = float(post["iou_threshold"])
    ios_thresh = float(post.get("ios_threshold", 0.65))
    use_ios = bool(post.get("ios_containment_filter", False))

    im = Image.open(image_path).convert("RGB")
    w, h = im.size

    if prep["resize_mode"] == "isometric_letterbox":
        scale = min(input_size / w, input_size / h)
        nw, nh = int(round(w * scale)), int(round(h * scale))
        pad_x, pad_y = (input_size - nw) / 2.0, (input_size - nh) / 2.0
        canvas = Image.new("RGB", (input_size, input_size), (114, 114, 114))
        canvas.paste(im.resize((nw, nh), Image.BILINEAR), (int(pad_x), int(pad_y)))
        scale_x = scale_y = scale
    else:
        pad_x = pad_y = 0.0
        scale_x, scale_y = input_size / w, input_size / h
        canvas = im.resize((input_size, input_size), Image.BILINEAR)

    arr = np.asarray(canvas, dtype=np.float32)
    lum = float(np.mean(arr))
    use_gamma = bool(prep.get("shadow_gamma_lut")) and (15.0 <= lum <= 92.0)
    if use_gamma:
        gamma = float(prep.get("gamma_value", 0.72))
        arr = np.power(arr / 255.0, gamma).astype(np.float32)
    else:
        arr = arr / 255.0

    inp = np.expand_dims(arr, 0)
    interp = tflite_runtime.Interpreter(str(model_path))
    interp.allocate_tensors()
    in_det = interp.get_input_details()[0]
    out_det = interp.get_output_details()[0]

    t0 = time.perf_counter()
    interp.set_tensor(in_det["index"], inp)
    interp.invoke()
    latency_ms = (time.perf_counter() - t0) * 1000.0

    out = interp.get_tensor(out_det["index"])[0]
    scores = out[4]
    idxs = np.where(scores >= conf_thresh)[0]
    mult = float(input_size) if float(np.max(out[0:2])) <= 2.0 else 1.0

    candidates: list[list[float]] = []
    for i in idxs:
        cx, cy = float(out[0, i]) * mult, float(out[1, i]) * mult
        bw, bh = float(out[2, i]) * mult, float(out[3, i]) * mult
        x1 = max(0.0, (cx - bw / 2.0 - pad_x) / scale_x)
        y1 = max(0.0, (cy - bh / 2.0 - pad_y) / scale_y)
        x2 = min(float(w), (cx + bw / 2.0 - pad_x) / scale_x)
        y2 = min(float(h), (cy + bh / 2.0 - pad_y) / scale_y)
        box_w, box_h = x2 - x1, y2 - y1
        if box_w <= 2.0 or box_h <= 2.0:
            continue
        if post.get("aspect_ratio_filter"):
            ratio = max(box_w / box_h, box_h / box_w)
            if ratio > 4.2:
                continue
        candidates.append([x1, y1, x2, y2, float(scores[i])])

    candidates.sort(key=lambda b: b[4], reverse=True)
    kept: list[list[float]] = []
    for box in candidates:
        overlap = False
        a1 = (box[2] - box[0]) * (box[3] - box[1])
        for prev in kept:
            ix1, iy1 = max(box[0], prev[0]), max(box[1], prev[1])
            ix2, iy2 = min(box[2], prev[2]), min(box[3], prev[3])
            inter = max(0.0, ix2 - ix1) * max(0.0, iy2 - iy1)
            a2 = (prev[2] - prev[0]) * (prev[3] - prev[1])
            iou = inter / (a1 + a2 - inter + 1e-6)
            ios = inter / (min(a1, a2) + 1e-6)
            if iou > iou_thresh or (use_ios and ios > ios_thresh):
                overlap = True
                break
        if not overlap:
            kept.append(box)
            if len(kept) >= max_results:
                break

    return DetectionResult(
        boxes=kept,
        latency_ms=latency_ms,
        mean_luminance=lum,
        used_gamma_lut=use_gamma,
        config_version=cfg["version"],
    )


def log_audit_event(
    caller_user: str,
    action: str,
    target_object: str,
    summary: str,
    status: str,
    error_detail: str | None = None,
    origin: str = "IA_Pipeline_CLI",
) -> None:
    """Registra evento de auditoria usando o papel Role_App_IA (GRANT INSERT)."""
    role = ALLOWED_PROFILES.get(caller_user, "Desconhecido")
    err_sql = f"N'{_sql_escape(error_detail)}'" if error_detail else "NULL"
    sql = f"""
    EXECUTE AS USER = 'usr_app_ia';
    INSERT INTO dbo.Auditoria_Log (
        usuario_solicitante, papel_executado, origem, acao,
        objeto_alvo, consulta_resumo, status_execucao, detalhe_erro
    )
    VALUES (
        N'{_sql_escape(caller_user)}',
        N'{_sql_escape(role)}',
        N'{_sql_escape(origin)}',
        N'{_sql_escape(action)}',
        N'{_sql_escape(target_object)}',
        N'{_sql_escape(summary)}',
        N'{_sql_escape(status)}',
        {err_sql}
    );
    REVERT;
    """
    run_sql_raw(sql)


def execute_as_caller(caller_user: str, inner_tsql: str) -> tuple[bool, str]:
    """Executa uma consulta pre-aprovada sob o contexto estrito do usuario solicitante."""
    if caller_user not in ALLOWED_PROFILES:
        raise ValueError(f"Perfil nao autorizado na allowlist: {caller_user}")

    wrapped = f"""
    SET NOCOUNT ON;
    BEGIN TRY
        EXECUTE AS USER = '{caller_user}';
        {inner_tsql}
        REVERT;
    END TRY
    BEGIN CATCH
        IF USER_NAME() <> 'dbo' REVERT;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @num INT = ERROR_NUMBER();
        RAISERROR(N'[SQL_ERR_%d] %s', 16, 1, @num, @msg);
    END CATCH
    """
    rc, out = run_sql_raw(wrapped)
    has_sql_err = rc != 0 or "[SQL_ERR_" in out or "foi negada" in out.lower() or "denied" in out.lower()
    return (not has_sql_err), out


def handle_query(caller_user: str, query_type: str, prompt_text: str = "") -> dict[str, Any]:
    """Processa consultas via ponte IA aplicando RBAC, RLS, DDM, anti-SQLi e Auditoria."""
    if prompt_text:
        for pat in SQLI_PATTERNS:
            if pat.search(prompt_text):
                detail = f"Padrao malicioso detectado no prompt: {pat.pattern}"
                log_audit_event(
                    caller_user=caller_user,
                    action="SQLI_BLOCKED",
                    target_object="IA_Prompt_Guard",
                    summary=f"Tentativa suspeita bloqueada antes da execucao: {prompt_text[:120]}",
                    status="BLOQUEADO_SQLI",
                    error_detail=detail,
                )
                return {
                    "caller_user": caller_user,
                    "role": ALLOWED_PROFILES[caller_user],
                    "query_type": f"SQLI_GUARD ({query_type})",
                    "status": "BLOQUEADO_SQLI",
                    "allowed": False,
                    "output": detail,
                }

    query_map: dict[str, tuple[str, str, str, str]] = {
        "resumo_fazendas": (
            "SELECT_RLS",
            "dbo.Fazendas",
            "Consulta de fazendas visiveis ao perfil (RLS)",
            "SELECT id_fazenda, codigo_fazenda, nome_fazenda, municipio_uf FROM dbo.Fazendas ORDER BY id_fazenda;",
        ),
        "estatisticas_publicas": (
            "SELECT_VIEW",
            "dbo.vw_Coletas_Publico_IA",
            "Resumo agronomico publico por clone sem dados pessoais",
            "SELECT TOP 5 clone, COUNT(*) AS coletas, SUM(qtd_sadios) AS sadios, SUM(qtd_vassoura) AS vassoura, SUM(qtd_podridao) AS podridao FROM dbo.vw_Coletas_Publico_IA GROUP BY clone ORDER BY coletas DESC;",
        ),
        "ler_usuarios_pii": (
            "SELECT_PII",
            "dbo.Usuarios",
            "Solicitacao de leitura de dados cadastrais e CPF de usuarios",
            "SELECT TOP 3 id_usuario, nome, cpf, email, papel FROM dbo.Usuarios ORDER BY id_usuario;",
        ),
        "ler_senha_hash": (
            "SELECT_HASH",
            "dbo.Usuarios.senha_hash",
            "Solicitacao de leitura direta de hashes de senha",
            "SELECT TOP 3 id_usuario, senha_hash FROM dbo.Usuarios ORDER BY id_usuario;",
        ),
        "apagar_coleta": (
            "DELETE_ATTEMPT",
            "dbo.Coletas",
            "Solicitacao de exclusao do registro id_coleta=1",
            "DELETE FROM dbo.Coletas WHERE id_coleta = 1;",
        ),
        "ler_auditoria": (
            "SELECT_AUDIT",
            "dbo.Auditoria_Log",
            "Solicitacao de leitura dos logs de auditoria",
            "SELECT TOP 5 id_log, data_hora, usuario_solicitante, acao, objeto_alvo, status_execucao FROM dbo.Auditoria_Log ORDER BY id_log DESC;",
        ),
    }

    if query_type not in query_map:
        raise ValueError(f"query_type desconhecido: {query_type}")

    action, target, summary, tsql = query_map[query_type]
    allowed, output = execute_as_caller(caller_user, tsql)
    status = "PERMITIDO" if allowed else "NEGADO"
    log_audit_event(
        caller_user=caller_user,
        action=action,
        target_object=target,
        summary=summary,
        status=status,
        error_detail=None if allowed else output.splitlines()[-1][:280],
    )
    return {
        "caller_user": caller_user,
        "role": ALLOWED_PROFILES[caller_user],
        "query_type": query_type,
        "status": status,
        "allowed": allowed,
        "output": output,
    }


def handle_infer_and_save(
    caller_user: str,
    image_path: str,
    fazenda_id: int,
    plant_id: str,
    clone: str,
    config_version: str,
) -> dict[str, Any]:
    """Executa Visao Computacional offline, grava no SQL Server e audita."""
    det = run_tflite_inference(image_path, config_version=config_version)
    total = len(det.boxes)
    mean_conf = float(np.mean([b[4] for b in det.boxes])) if total > 0 else 0.0
    lat_int = max(1, int(round(det.latency_ms)))
    model_name = f"detector-cacau-{det.config_version}.tflite"
    plant_safe = _sql_escape(plant_id)
    clone_safe = _sql_escape(clone)

    tsql = f"""
    INSERT INTO dbo.Coletas (
        id_fazenda, id_usuario, plant_id, clone, parcela, planta_num,
        qtd_sadios, qtd_vassoura, qtd_podridao, qtd_total_ia, qtd_total_auditada,
        confianca_media, latencia_ms, modelo_ia, status_validacao, observacao
    )
    VALUES (
        {int(fazenda_id)}, 5, N'{plant_safe}', N'{clone_safe}', 1, 1,
        {total}, 0, 0, {total}, {total},
        {mean_conf:.4f}, {lat_int}, N'{model_name}', 'Pendente',
        N'Inferencia via Ponte IA CLI ({det.config_version}, gamma={det.used_gamma_lut})'
    );
    SELECT SCOPE_IDENTITY() AS novo_id_coleta;
    """
    allowed, output = execute_as_caller(caller_user, tsql)
    status = "PERMITIDO" if allowed else "NEGADO"
    log_audit_event(
        caller_user=caller_user,
        action="IA_INFER_INSERT",
        target_object="dbo.Coletas",
        summary=f"Inferencia {Path(image_path).name}: {total} frutos ({lat_int}ms) -> Fazenda {fazenda_id}",
        status=status,
        error_detail=None if allowed else output[:280],
    )
    return {
        "caller_user": caller_user,
        "role": ALLOWED_PROFILES[caller_user],
        "image": Path(image_path).name,
        "detected_pods": total,
        "mean_confidence": round(mean_conf, 4),
        "latency_ms": round(det.latency_ms, 2),
        "used_gamma_lut": det.used_gamma_lut,
        "db_status": status,
        "db_output": output,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Ponte CLI IA <-> SQL Server (CacauApp2)")
    parser.add_argument("--user", required=True, choices=sorted(ALLOWED_PROFILES.keys()))
    parser.add_argument("--action", required=True, choices=["infer-and-save", "query", "audit-tail"])
    parser.add_argument("--image", default=str(ROOT_DIR / "ia" / "samples" / "sample_01_cacau_vermelho.jpg"))
    parser.add_argument("--fazenda", type=int, default=1)
    parser.add_argument("--plant-id", default="CCN-51_P1_Pl01")
    parser.add_argument("--clone", default="CCN-51")
    parser.add_argument("--config", default="v2", choices=["v1", "v2"])
    parser.add_argument(
        "--query-type",
        default="estatisticas_publicas",
        choices=[
            "resumo_fazendas",
            "estatisticas_publicas",
            "ler_usuarios_pii",
            "ler_senha_hash",
            "apagar_coleta",
            "ler_auditoria",
        ],
    )
    parser.add_argument("--prompt", default="")
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()

    if args.action == "infer-and-save":
        res = handle_infer_and_save(
            args.user, args.image, args.fazenda, args.plant_id, args.clone, args.config
        )
    elif args.action == "query":
        res = handle_query(args.user, args.query_type, args.prompt)
    else:
        allowed, output = execute_as_caller(
            args.user,
            f"SELECT TOP {int(args.limit)} id_log, CONVERT(VARCHAR(19), data_hora, 120) AS quando, usuario_solicitante, papel_executado, acao, objeto_alvo, status_execucao FROM dbo.Auditoria_Log ORDER BY id_log DESC;",
        )
        res = {"caller_user": args.user, "allowed": allowed, "output": output}

    print(json.dumps(res, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
