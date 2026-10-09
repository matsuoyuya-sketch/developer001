<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>週報</title>
<style>
  body {
    font-family: "Hiragino Kaku Gothic ProN", "Yu Gothic", Meiryo, sans-serif;
    background: #f4f5f7;
    margin: 0;
    padding: 24px;
    color: #1a1a1a;
  }
  .container {
    max-width: 760px;
    margin: 0 auto;
    background: #fff;
    border-radius: 8px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.1);
    padding: 24px;
    position: relative;
  }
  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }
  .header h1 {
    font-size: 18px;
    margin: 0;
  }
  .header .period {
    font-size: 12px;
    color: #6b7280;
    margin-top: 4px;
  }
  #copyBtn {
    background: #2563eb;
    color: #fff;
    border: none;
    border-radius: 6px;
    padding: 8px 16px;
    font-size: 14px;
    cursor: pointer;
  }
  #copyBtn:hover { background: #1d4ed8; }
  #copyBtn.done { background: #16a34a; }
  pre.report {
    white-space: pre-wrap;
    word-break: break-word;
    font-family: "Hiragino Kaku Gothic ProN", "Yu Gothic", Meiryo, sans-serif;
    font-size: 14px;
    line-height: 1.7;
    background: #fafafa;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    padding: 16px;
    margin: 0;
  }
  #toast {
    position: fixed;
    left: 50%;
    bottom: 32px;
    transform: translateX(-50%);
    background: #1a1a1a;
    color: #fff;
    padding: 10px 20px;
    border-radius: 6px;
    font-size: 14px;
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.3s;
  }
  #toast.show { opacity: 0.95; }
</style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div>
        <h1>週報</h1>
        <div class="period">{{PERIOD}}</div>
      </div>
      <button id="copyBtn">コピー</button>
    </div>
    <pre class="report" id="report">{{BODY}}</pre>
  </div>
  <div id="toast">コピーしました</div>

<script>
  const btn = document.getElementById('copyBtn');
  const reportEl = document.getElementById('report');
  const toast = document.getElementById('toast');

  function showDone() {
    btn.textContent = 'コピー完了';
    btn.classList.add('done');
    toast.classList.add('show');
    setTimeout(() => {
      btn.textContent = 'コピー';
      btn.classList.remove('done');
      toast.classList.remove('show');
    }, 2000);
  }

  function fallbackCopy() {
    const range = document.createRange();
    range.selectNodeContents(reportEl);
    const sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    try {
      document.execCommand('copy');
      showDone();
    } catch (e) {
      alert('コピーに失敗しました');
    }
    sel.removeAllRanges();
  }

  btn.addEventListener('click', () => {
    const text = reportEl.textContent;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(showDone).catch(fallbackCopy);
    } else {
      fallbackCopy();
    }
  });
</script>
</body>
</html>
