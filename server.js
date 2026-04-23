const http = require("http");

let pipeline = {
  build: "PENDING",
  test: "PENDING",
  deploy: "PENDING"
};

let logs = ["System ready..."];

function getTime() {
  return new Date().toLocaleString();
}

// ================= PIPELINE =================
function runPipeline() {
  logs = [`🚀 Pipeline started at ${getTime()}`];

  pipeline = { build: "RUNNING", test: "PENDING", deploy: "PENDING" };
  logs.push(`🔨 Build started (${getTime()})`);

  setTimeout(() => {
    pipeline.build = "SUCCESS";
    logs.push(`✅ Build successful (${getTime()})`);

    pipeline.test = "RUNNING";
    logs.push(`🧪 Tests running (${getTime()})`);
  }, 2000);

  setTimeout(() => {
    pipeline.test = "SUCCESS";
    logs.push(`✅ Tests passed (${getTime()})`);

    pipeline.deploy = "RUNNING";
    logs.push(`🚀 Deploying (${getTime()})`);
  }, 5000);

  setTimeout(() => {
    pipeline.deploy = "SUCCESS";
    logs.push(`🎉 Deployment successful (${getTime()})`);
  }, 8000);
}

// ================= SERVER =================
http.createServer((req, res) => {

  // ================= DASHBOARD =================
  if (req.url === "/") {
    res.writeHead(200, { "Content-Type": "text/html" });

    res.end(`
<!DOCTYPE html>
<html>
<head>
<title>CI/CD Dashboard</title>

<style>
body {
  margin: 0;
  font-family: 'Segoe UI';
  background: linear-gradient(135deg, #0f172a, #1e293b);
  color: white;
  text-align: center;
}

.card {
  margin: 60px auto;
  padding: 30px;
  width: 520px;
  border-radius: 12px;
  background: rgba(255,255,255,0.05);
}

.stage {
  display: flex;
  justify-content: space-between;
  margin: 10px 0;
  padding: 10px;
  border-radius: 8px;
}

.pending { background: #334155; }
.running { background: #facc15; color: black; }
.success { background: #22c55e; }

.info {
  margin-top: 20px;
  font-size: 14px;
  color: #cbd5f5;
}

button {
  margin-top: 20px;
  padding: 12px 20px;
  background: #22c55e;
  border: none;
  border-radius: 6px;
  cursor: pointer;
}

#time {
  margin-top: 10px;
}
</style>
</head>

<body>

<div class="card">
  <h2>🚀 CI/CD Dashboard</h2>

  <div id="build" class="stage pending">
    <span>Build</span><span>PENDING</span>
  </div>

  <div id="test" class="stage pending">
    <span>Test</span><span>PENDING</span>
  </div>

  <div id="deploy" class="stage pending">
    <span>Deploy</span><span>PENDING</span>
  </div>

  <div class="info">
    <div>Status: <b id="status">--</b></div>
    <div>Version: <span id="version">--</span></div>
    <div>Environment: <span id="env">--</span></div>
    <div id="time">Time: --</div>
  </div>

  <button onclick="startPipeline()">Start Pipeline</button>
</div>

<script>

function update(id, status) {
  let el = document.getElementById(id);
  el.className = "stage " + status.toLowerCase();
  el.children[1].innerText = status;
}

function loadPipeline() {
  fetch("/pipeline")
    .then(res => res.json())
    .then(data => {
      update("build", data.build);
      update("test", data.test);
      update("deploy", data.deploy);
    });
}

function loadBackendInfo() {
  fetch("http://localhost:8080/api/info")
    .then(res => res.json())
    .then(data => {
      document.getElementById("status").innerText = data.status;
      document.getElementById("version").innerText = data.version;
      document.getElementById("env").innerText = data.environment;
    })
    .catch(() => {
      document.getElementById("status").innerText = "OFFLINE";
    });
}

function updateTime() {
  document.getElementById("time").innerText =
    "Time: " + new Date().toLocaleString();
}

function startPipeline() {
  fetch("/start");
  window.open("/logs", "_blank");
}

setInterval(loadPipeline, 1000);
setInterval(loadBackendInfo, 2000);
setInterval(updateTime, 1000);

</script>

</body>
</html>
    `);
  }

  // ================= LOG PAGE =================
  else if (req.url === "/logs") {
    res.writeHead(200, { "Content-Type": "text/html" });

    res.end(`
<!DOCTYPE html>
<html>
<head>
<title>Live Logs</title>

<style>
body {
  margin: 0;
  background: #0f172a;
  color: #00ff00;
  font-family: monospace;
}

.header {
  text-align: center;
  padding: 15px;
  color: white;
  font-size: 22px;
  background: #020617;
}

.info {
  display: flex;
  justify-content: space-around;
  padding: 10px;
  background: #020617;
  color: #cbd5f5;
}

.box {
  background: #020617;
  padding: 10px;
  border-radius: 6px;
}

#logBox {
  padding: 20px;
  height: 65vh;
  overflow-y: auto;
  white-space: pre-line;
}

.progress {
  width: 80%;
  height: 10px;
  background: #334155;
  margin: 10px auto;
  border-radius: 10px;
}

.progress-bar {
  height: 10px;
  background: #22c55e;
  width: 0%;
  border-radius: 10px;
}
</style>
</head>

<body>

<div class="header">📜 Live Server Output</div>

<div class="info">
  <div class="box">Stage: <span id="stage">--</span></div>
  <div class="box">Status: <span id="status">--</span></div>
  <div class="box">Version: <span id="version">--</span></div>
  <div class="box">Env: <span id="env">--</span></div>
  <div class="box">Time: <span id="time">--</span></div>
</div>

<div class="progress">
  <div id="bar" class="progress-bar"></div>
</div>

<div id="logBox">Loading...</div>

<script>

function updateProgress(pipeline) {
  let percent = 0;

  if (pipeline.build === "SUCCESS") percent = 33;
  if (pipeline.test === "SUCCESS") percent = 66;
  if (pipeline.deploy === "SUCCESS") percent = 100;

  document.getElementById("bar").style.width = percent + "%";

  if (pipeline.deploy === "SUCCESS") {
    document.getElementById("stage").innerText = "Done";
  } else if (pipeline.deploy === "RUNNING") {
    document.getElementById("stage").innerText = "Deploying";
  } else if (pipeline.test === "RUNNING") {
    document.getElementById("stage").innerText = "Testing";
  } else {
    document.getElementById("stage").innerText = "Building";
  }
}

function loadLogs() {
  fetch("/logs-data")
    .then(res => res.json())
    .then(data => {
      document.getElementById("logBox").innerText = data.join("\\n");
    });
}

function loadPipeline() {
  fetch("/pipeline")
    .then(res => res.json())
    .then(data => {
      updateProgress(data);
    });
}

function loadBackendInfo() {
  fetch("http://localhost:8080/api/info")
    .then(res => res.json())
    .then(data => {
      document.getElementById("status").innerText = data.status;
      document.getElementById("version").innerText = data.version;
      document.getElementById("env").innerText = data.environment;
    })
    .catch(() => {
      document.getElementById("status").innerText = "OFFLINE";
    });
}

function updateTime() {
  document.getElementById("time").innerText =
    new Date().toLocaleString();
}

setInterval(loadLogs, 1000);
setInterval(loadPipeline, 1000);
setInterval(loadBackendInfo, 2000);
setInterval(updateTime, 1000);

</script>

</body>
</html>
    `);
  }

  // ================= APIs =================
  else if (req.url === "/pipeline") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(pipeline));
  }

  else if (req.url === "/logs-data") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(logs));
  }

  else if (req.url === "/start") {
    runPipeline();
    res.end("Started");
  }

}).listen(3000, () => {
  console.log("🚀 Dashboard running at http://localhost:3000");
});