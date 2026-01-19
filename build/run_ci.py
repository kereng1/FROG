#!/usr/bin/env python3
"""
Run all CI steps locally with live-updating terminal display.
Parses .github/workflows/ci.yaml and executes each build step.
"""
import yaml
import subprocess
import sys
import os
import re

# ANSI codes
class C:
    RESET = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    UP = '\033[{n}A'
    CLEAR = '\033[K'

class Status:
    PENDING = f"{C.DIM}○ PENDING{C.RESET}"
    RUNNING = f"{C.YELLOW}● RUNNING{C.RESET}"
    PASS = f"{C.GREEN}✓ PASS{C.RESET}"
    FAIL = f"{C.RED}✗ FAIL{C.RESET}"

def parse_workflow(yaml_path):
    """Extract build steps from CI workflow."""
    with open(yaml_path, 'r') as f:
        workflow = yaml.safe_load(f)
    
    steps = []
    for job_name, job in workflow.get('jobs', {}).items():
        for step in job.get('steps', []):
            if 'run' in step and 'builder.py' in step['run']:
                name = step.get('name', 'Unknown')
                cmd = step['run']
                # Extract DUT name from command
                match = re.search(r'-dut\s+(\S+)', cmd)
                dut = match.group(1) if match else 'unknown'
                steps.append({
                    'name': name,
                    'cmd': cmd,
                    'dut': dut,
                    'status': 'pending',
                    'log_path': ''
                })
    return steps

def print_status(steps, current_idx=-1):
    """Print all steps with their current status."""
    # Move cursor up to overwrite previous output
    if current_idx >= 0:
        print(f"\033[{len(steps)}A", end='')
    
    for i, step in enumerate(steps):
        status = Status.PENDING
        if step['status'] == 'running':
            status = Status.RUNNING
        elif step['status'] == 'pass':
            status = Status.PASS
        elif step['status'] == 'fail':
            status = Status.FAIL
        
        # Build the line
        name = step['name'].ljust(25)
        log_info = ""
        if step['log_path']:
            log_info = f"{C.DIM} → {step['log_path']}{C.RESET}"
        
        print(f"{C.CLEAR}{status}  {name}{log_info}")

def extract_log_paths(output, dut):
    """Extract build log path from builder output."""
    build_log = ''
    # Look for the build.log path in output
    for line in output.split('\n'):
        if '→' in line and 'build.log' in line:
            match = re.search(r'→\s*(\S+/build\.log)', line)
            if match:
                build_log = match.group(1)
    
    # If no build log found, try to find build_latest/build.log
    if not build_log:
        latest_log = f"target/{dut}/logs/build_latest/build.log"
        if os.path.exists(latest_log):
            build_log = latest_log
    
    return build_log

def run_steps(steps):
    """Run all steps and update display."""
    print(f"\n{C.BOLD}Running CI Pipeline{C.RESET}\n")
    print(f"{'─' * 60}\n")
    
    # Initial print
    print_status(steps)
    
    passed = 0
    failed = 0
    
    for i, step in enumerate(steps):
        step['status'] = 'running'
        print_status(steps, i)
        
        try:
            result = subprocess.run(
                step['cmd'],
                shell=True,
                capture_output=True,
                text=True,
                cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            )
            
            # Extract log path from output
            step['log_path'] = extract_log_paths(result.stdout + result.stderr, step['dut'])
            
            if result.returncode == 0:
                step['status'] = 'pass'
                passed += 1
            else:
                step['status'] = 'fail'
                failed += 1
                
        except Exception as e:
            step['status'] = 'fail'
            failed += 1
        
        print_status(steps, i)
    
    # Summary
    print(f"\n{'─' * 60}")
    total = len(steps)
    if failed == 0:
        print(f"\n{C.GREEN}{C.BOLD}All {total} tests passed!{C.RESET}\n")
    else:
        print(f"\n{C.RED}{C.BOLD}{failed}/{total} tests failed{C.RESET}\n")
    
    return failed == 0

def main():
    # Find workflow file
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    workflow_path = os.path.join(project_root, '.github', 'workflows', 'ci.yaml')
    
    if not os.path.exists(workflow_path):
        print(f"Error: Workflow file not found: {workflow_path}")
        sys.exit(1)
    
    steps = parse_workflow(workflow_path)
    
    if not steps:
        print("No build steps found in workflow.")
        sys.exit(1)
    
    success = run_steps(steps)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

