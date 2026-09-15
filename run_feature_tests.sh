#!/bin/bash
set -e

echo "🥒 Running SmurfAudio Cucumber BDD Feature Suite via automation-mcp..."
node -e '
import { spawn } from "child_process";
import fs from "fs";

const featureContent = fs.readFileSync("features/smurfaudio_control.feature", "utf-8");
const stepsContent = fs.readFileSync("features/steps.ts", "utf-8");

const proc = spawn("/opt/homebrew/bin/automation-mcp", ["--screenshots-dir", "/tmp/.temp_runs"]);

let buffer = "";
proc.stdout.on("data", (data) => {
  buffer += data.toString();
  const lines = buffer.split("\n");
  buffer = lines.pop();
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const msg = JSON.parse(line);
      if (msg.id === 1) {
        proc.stdin.write(JSON.stringify({
          jsonrpc: "2.0",
          id: 2,
          method: "tools/call",
          params: {
            name: "run_cucumber_test",
            arguments: {
              feature_content: featureContent,
              step_definitions: stepsContent
            }
          }
        }) + "\n");
      } else if (msg.id === 2) {
        const res = JSON.parse(msg.result.content[0].text);
        if (res.success) {
          console.log("✅ All BDD Feature Scenarios Passed!\n");
          console.log(res.stdout);
          proc.kill();
          process.exit(0);
        } else {
          console.error("❌ Feature Tests Failed!\n", res.stdout, res.stderr);
          proc.kill();
          process.exit(1);
        }
      }
    } catch (e) {
      console.error(e);
    }
  }
});

proc.stdin.write(JSON.stringify({
  jsonrpc: "2.0",
  id: 1,
  method: "initialize",
  params: {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "smurfaudio-tester", version: "1.1.0" }
  }
}) + "\n");
'
