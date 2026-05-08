import subprocess
import json
import sys

def invoke_agent(prompt):
    print(f"Invoking Bedrock Agent with prompt: {prompt}\n")
    try:
        # We run agentcore invoke from the bedrocksre directory
        process = subprocess.Popen(
            ["agentcore", "invoke", prompt, "--stream"],
            cwd="bedrocksre",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        for line in process.stdout:
            print(line, end="", flush=True)
            
        process.wait()
        if process.returncode != 0:
            print(f"\nError: {process.stderr.read()}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    prompt = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "What can you do?"
    invoke_agent(prompt)
