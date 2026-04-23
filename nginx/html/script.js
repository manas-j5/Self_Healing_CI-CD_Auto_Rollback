async function loadData() {
  try {
    const statusEl = document.getElementById('status');
    statusEl.innerText = "Loading...";

    const res = await fetch('/api/info');
    const data = await res.json();

    if (data.status === "running") {
      statusEl.innerText = "Running ✅";
      statusEl.style.background = "green";
      document.getElementById('health').value = 100;
    } else {
      statusEl.innerText = "Failed ❌";
      statusEl.style.background = "red";
      document.getElementById('health').value = 40;
    }

    document.getElementById('version').innerText = data.version || "--";
    document.getElementById('time').innerText = data.deployment_time || "--";

    document.getElementById('updated').innerText =
      new Date().toLocaleTimeString();

  } catch (err) {
    console.error(err);
  }
}

loadData();
setInterval(loadData, 5000);