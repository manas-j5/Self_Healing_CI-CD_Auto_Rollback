async function fetchData() {
    try {
        const res = await fetch('/api/info');
        const data = await res.json();

        // Status
        const statusEl = document.getElementById('status');
        statusEl.innerText = data.status;

        if (data.status === "RUNNING") {
            statusEl.className = "status green";
        } else {
            statusEl.className = "status red";
        }

        // Version
        document.getElementById('version').innerText = data.version;

        // Time
        document.getElementById('time').innerText =
            new Date(data.timestamp).toLocaleString();

        // Health bar
        document.getElementById('healthBar').value =
            data.status === "RUNNING" ? 100 : 0;

        // Last updated
        document.getElementById('lastUpdated').innerText =
            new Date().toLocaleTimeString();

    } catch (err) {
        console.error(err);
        document.getElementById('status').innerText = "Error ❌";
    }
}

// Auto refresh
setInterval(fetchData, 5000);

// Initial load
fetchData();