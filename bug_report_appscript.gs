/************************************************************
 * GFL2 리몰딩 플래너 — 버그 신고 수신 (Google Apps Script)
 *
 * 배포 방법
 *  1) 신고를 받을 구글 시트를 새로 하나 만든다.
 *  2) 시트 상단 메뉴: 확장 프로그램 → Apps Script.
 *  3) 기본 코드를 지우고 이 파일 내용을 통째로 붙여넣는다.
 *  4) 아래 SECRET 값을 자기만 아는 문자열로 바꾼다.
 *     (index.html 의 BUG_REPORT_SECRET 과 반드시 동일해야 함)
 *  5) 우상단 [배포] → [새 배포] → 유형: 웹 앱
 *       - 실행 계정: 나
 *       - 액세스 권한: 모든 사용자
 *     → 배포하면 나오는 웹 앱 URL(.../exec) 을 복사.
 *  6) index.html 의 BUG_REPORT_URL 에 그 URL 을 붙여넣는다.
 *
 * 코드를 고치면 [배포] → [배포 관리] → 편집(연필) → 버전 "새 버전" → 배포 로 갱신.
 *
 * 시트에 쌓이는 형태(한 신고 = 한 행):
 *   A:시각  B:버전  C:메모  D:UA  E:청크수  F,G,H,…: 상태 청크(40,000자씩 잘림)
 *
 * ▶ 재현(개발자): 그 행의 F열부터 끝까지(청크 칸들)를 드래그 복사 → 플래너 콘솔에서
 *     __loadDiagnostic(`여기 붙여넣기`)  실행 → 그 화면이 그대로 복원됨.
 *   (앞쪽 A~E 칸이 섞여 들어가도 파서가 걸러내지만, 되도록 F열부터 복사 권장.)
 ************************************************************/

var SECRET = 'gfl2bug_YDLvzrG_jaeh';   // ← index.html 의 BUG_REPORT_SECRET 과 동일하게(스팸차단, 공개돼도 무방)

// ▼ 관리자 조회 전용 키 — index.html 에는 절대 넣지 말 것(넣으면 남들이 전체 리포트를 봄).
//   Apps Script 편집기에서만 자기만 아는 값으로 바꾸고, 그 값을 개발자(클로드)에게만 전달.
var ADMIN_KEY = 'gfl2admin_CHANGE_ME';

// 새 신고마다 알림 이메일 발송(스크립트 소유자 = 배포한 본인에게). 끄려면 false.
// 첫 배포 시 이메일 전송 권한 승인 1회 필요. (Discord로 받고 싶으면 DISCORD_WEBHOOK 채우고 아래 doPost 참고)
var NOTIFY_EMAIL = true;
var DISCORD_WEBHOOK = '';   // 예: 'https://discord.com/api/webhooks/…' (있으면 이메일 대신/추가로 디스코드 알림)

var HEADERS = ['시각','버전','메모','UA','청크수','상태(청크1)'];

function doPost(e) {
  try {
    var data = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    if (data.secret !== SECRET) {
      return ContentService.createTextOutput('forbidden').setMimeType(ContentService.MimeType.TEXT);
    }
    var sh = SpreadsheetApp.getActiveSpreadsheet().getSheets()[0];
    if (sh.getLastRow() === 0) sh.appendRow(HEADERS);

    var cap = function (s) { s = String(s == null ? '' : s); return s.length > 49000 ? s.slice(0, 49000) + '…' : s; };
    var chunks = Array.isArray(data.chunks) ? data.chunks.map(cap) : [];

    var row = [new Date(), data.v == null ? '' : data.v, cap(data.note), cap(data.ua), data.n || chunks.length];
    row = row.concat(chunks);   // 청크 개수만큼 F열부터 이어서 기록
    sh.appendRow(row);

    // ── 새 신고 알림 ──────────────────────────────────
    try {
      var invN = '';
      try { var stt = JSON.parse(chunks.join('')); if (stt && Array.isArray(stt.inv)) invN = '\n보유 리몰딩: ' + stt.inv.length + '개'; } catch (e) {}
      var line = '메모: ' + (data.note || '(없음)') + '\n행: ' + sh.getLastRow() + '\n버전: ' + (data.v == null ? '' : data.v) + '\nUA: ' + (data.ua || '') + invN;
      if (NOTIFY_EMAIL) {
        var to = Session.getEffectiveUser().getEmail();
        if (to) MailApp.sendEmail(to, 'GFL2 플래너 — 새 버그 신고', '새 버그 신고가 접수되었습니다.\n\n' + line + '\n\n확인: 클로드에게 "버그 신고 봐줘".');
      }
      if (DISCORD_WEBHOOK) {
        UrlFetchApp.fetch(DISCORD_WEBHOOK, { method: 'post', contentType: 'application/json',
          payload: JSON.stringify({ content: '🐛 **새 버그 신고**\n' + line }), muteHttpExceptions: true });
      }
    } catch (e) { /* 알림 실패해도 신고 접수는 성공 처리 */ }
    // ──────────────────────────────────────────────────

    return ContentService.createTextOutput('ok').setMimeType(ContentService.MimeType.TEXT);
  } catch (err) {
    return ContentService.createTextOutput('error: ' + err).setMimeType(ContentService.MimeType.TEXT);
  }
}

// GET:
//  · 파라미터 없음      → 생존 확인 텍스트
//  · ?admin=KEY&list=1  → 리포트 목록(메타: 행번호·시각·버전·메모·UA·상태길이) JSON (개발자 점검용)
//  · ?admin=KEY&row=N   → N행의 전체 상태 JSON(청크 재조립) — 이걸 __loadDiagnostic 없이 바로 분석
//  · ?admin=KEY&list=1&n=20 → 최근 20건만
function doGet(e) {
  var out = function (obj) {
    return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
  };
  var p = (e && e.parameter) || {};
  if (!p.admin) {
    return ContentService.createTextOutput('GFL2 remold planner — bug report endpoint alive')
      .setMimeType(ContentService.MimeType.TEXT);
  }
  if (p.admin !== ADMIN_KEY) return out({ error: 'forbidden' });

  var sh = SpreadsheetApp.getActiveSpreadsheet().getSheets()[0];
  var last = sh.getLastRow();
  if (last < 2) return out({ count: 0, rows: [] });
  var vals = sh.getDataRange().getValues();   // [0]=헤더
  // 한 행 → {row, ts, v, note, ua, state(청크 재조립)}
  var mk = function (i) {
    var r = vals[i]; var chunks = r.slice(5).filter(function (c) { return c !== '' && c != null; });
    return { row: i + 1, ts: r[0], v: r[1], note: r[2], ua: r[3], n: r[4], state: chunks.join('') };
  };

  if (p.row) {
    var i = parseInt(p.row, 10) - 1;
    if (i < 1 || i >= vals.length) return out({ error: 'row out of range' });
    return out(mk(i));   // 전체 상태 포함
  }

  // list: 메타만(상태는 길이만) — 응답 비대 방지
  var n = p.n ? parseInt(p.n, 10) : 0;
  var start = 1, end = vals.length;
  if (n > 0) start = Math.max(1, end - n);
  var rows = [];
  for (var i = end - 1; i >= start; i--) {   // 최신순
    var m = mk(i);
    rows.push({ row: m.row, ts: m.ts, v: m.v, note: m.note, ua: m.ua, chars: (m.state || '').length });
  }
  return out({ count: vals.length - 1, rows: rows });
}
