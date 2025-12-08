#!/usr/bin/env python3
"""
Generic Build System - Workflow driven by YAML configuration.
"""
import argparse
import yaml
import os
import sys
import subprocess
import datetime

# ANSI Color codes
class Colors:
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    RESET = '\033[0m'

# Strip ANSI codes for log file
def strip_ansi(text):
    import re
    return re.sub(r'\033\[[0-9;]*m', '', text)

class BuildLogger:
    """Captures all build output to timestamped log directory."""
    
    def __init__(self, logs_dir, timestamp):
        self.logs_dir = logs_dir
        self.timestamp = timestamp
        self.log_file = None
        self.build_dir = None
        self.log_path = None
        
    def start(self):
        """Create build log directory and open log file."""
        # Create build_<timestamp>/ directory
        self.build_dir = os.path.join(self.logs_dir, f"build_{self.timestamp}")
        os.makedirs(self.build_dir, exist_ok=True)
        
        # Create build.log file inside the directory
        self.log_path = os.path.join(self.build_dir, "build.log")
        self.log_file = open(self.log_path, 'w')
        self.write(f"Build started at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        self.write("=" * 60 + "\n\n")
        
    def write(self, msg):
        """Write to log file (strips ANSI codes)."""
        if self.log_file:
            self.log_file.write(strip_ansi(msg))
            self.log_file.flush()
    
    def finish(self, success=True):
        """Close log file and create build_latest symlink."""
        if self.log_file:
            self.write("\n" + "=" * 60 + "\n")
            status = "SUCCESS" if success else "FAILED"
            self.write(f"Build {status} at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            self.log_file.close()
            
            # Create/update symlink to latest build directory
            latest_link = os.path.join(self.logs_dir, "build_latest")
            if os.path.islink(latest_link):
                os.unlink(latest_link)
            elif os.path.exists(latest_link):
                import shutil
                shutil.rmtree(latest_link)
            os.symlink(os.path.basename(self.build_dir), latest_link)
            
        return self.log_path

# Global state
VERBOSE = False
BUILD_LOGGER = None

def log(msg, color=None, bold=False):
    """Print to console and write to log file."""
    prefix = ""
    suffix = Colors.RESET if color or bold else ""
    if bold:
        prefix += Colors.BOLD
    if color:
        prefix += color
    formatted = f"{prefix}{msg}{suffix}"
    print(formatted)
    sys.stdout.flush()
    
    if BUILD_LOGGER:
        BUILD_LOGGER.write(msg + "\n")

def log_verbose(msg):
    """Print verbose output to console and always write to log."""
    if VERBOSE:
        print(f"{Colors.DIM}  {msg}{Colors.RESET}")
        sys.stdout.flush()
    
    if BUILD_LOGGER:
        BUILD_LOGGER.write(f"  {msg}\n")

def log_output(msg, indent=4):
    """Log command output (always to log file, verbose to console)."""
    if VERBOSE:
        print(f"{Colors.DIM}{' ' * indent}{msg}{Colors.RESET}")
        sys.stdout.flush()
    
    if BUILD_LOGGER:
        BUILD_LOGGER.write(f"{' ' * indent}{msg}\n")

def load_config(config_path):
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)

def resolve_variables(variables):
    """Iteratively resolve variables until stable."""
    max_iters = 20
    resolved = variables.copy()
    
    for _ in range(max_iters):
        changes = 0
        for key, value in resolved.items():
            if isinstance(value, str) and '{' in value and '}' in value:
                try:
                    new_value = value.format(**resolved)
                    if new_value != value:
                        resolved[key] = new_value
                        changes += 1
                except KeyError:
                    pass
                except ValueError:
                    log(f"Error: Malformed format string for '{key}': {value}", Colors.RED)
                    sys.exit(1)
        if changes == 0:
            break
    return resolved

def get_dependencies(stage_name, stages_config, visited=None, path=None):
    if visited is None:
        visited = set()
    if path is None:
        path = []
        
    if stage_name in path:
        log(f"Error: Circular dependency: {' -> '.join(path)} -> {stage_name}", Colors.RED)
        sys.exit(1)
        
    if stage_name not in stages_config:
        log(f"Error: Stage '{stage_name}' not found.", Colors.RED)
        sys.exit(1)
    
    stage = stages_config[stage_name]
    deps = stage.get('dependencies', [])
    
    ordered_stages = []
    path.append(stage_name)
    
    for dep in deps:
        if dep not in visited:
            ordered_stages.extend(get_dependencies(dep, stages_config, visited, path))
    
    path.pop()
    
    if stage_name not in visited:
        ordered_stages.append(stage_name)
        visited.add(stage_name)
        
    return ordered_stages

def run_stage(stage_name, stages_config, variables):
    """Execute a single stage."""
    stage = stages_config[stage_name]
    commands = stage.get('commands', [])
    
    log(f"▸ {stage_name}", Colors.CYAN, bold=True)
    
    for cmd_template in commands:
        try:
            cmd = cmd_template.format(**variables)
        except KeyError as e:
            log(f"  ✗ Missing variable {e}", Colors.RED)
            sys.exit(1)
        
        log_verbose(f"$ {cmd}")
        
        try:
            result = subprocess.run(
                cmd, 
                shell=True, 
                executable='/bin/bash',
                capture_output=True,
                text=True
            )
            
            # Log stdout
            if result.stdout:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        log_output(line)
            
            # Log stderr
            if result.stderr:
                for line in result.stderr.strip().split('\n'):
                    if line:
                        log_output(line)
            
            if result.returncode != 0:
                log(f"  ✗ Command failed (exit code: {result.returncode})", Colors.RED)
                if BUILD_LOGGER:
                    BUILD_LOGGER.finish(success=False)
                sys.exit(result.returncode)
                
        except Exception as e:
            log(f"  ✗ {e}", Colors.RED)
            if BUILD_LOGGER:
                BUILD_LOGGER.finish(success=False)
            sys.exit(1)
    
    log(f"  ✓ done", Colors.GREEN)
    
    # Print log file path if stage has one
    log_file_template = stage.get('log_file')
    if log_file_template:
        try:
            log_file_path = log_file_template.format(**variables)
            print(f"{Colors.DIM}    → {log_file_path}{Colors.RESET}")
        except KeyError:
            pass

def build_parser(config):
    """Build argparse dynamically from YAML stages."""
    parser = argparse.ArgumentParser(
        description="Build System",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    # Generic flags
    parser.add_argument("-dut", "--dut", metavar="NAME", required=True, help="Device Under Test")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    
    # Dynamic flags from stages (skip hidden ones)
    stages_config = config.get('stages', {})
    for stage_name, stage_info in stages_config.items():
        if stage_info.get('hidden', False):
            continue
        parser.add_argument(
            f"-{stage_name}",
            action="store_true",
            help=stage_info.get('description', f"Run {stage_name}")
        )
    
    return parser

def main():
    global VERBOSE, BUILD_LOGGER
    
    # Load config
    script_dir = os.path.dirname(os.path.abspath(__file__))
    yaml_path = os.path.join(script_dir, "workflow.yaml")
    
    if not os.path.exists(yaml_path):
        print(f"Error: Config not found: {yaml_path}")
        sys.exit(1)
    
    try:
        config = load_config(yaml_path)
    except yaml.YAMLError as e:
        print(f"Error: Invalid YAML: {e}")
        sys.exit(1)
    
    # Build parser and parse args
    parser = build_parser(config)
    args = parser.parse_args()
    VERBOSE = args.verbose
    
    # Setup variables
    variables = config.get('variables', {}).copy()
    variables['cwd'] = os.getcwd()
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    variables['timestamp'] = timestamp
    
    # Collect requested stages
    stages_config = config.get('stages', {})
    requested_stages = []
    active_flags = []
    
    for stage_name, stage_info in stages_config.items():
        if stage_info.get('hidden', False):
            continue
        if getattr(args, stage_name, False):
            requested_stages.append(stage_name)
            active_flags.append(stage_name)
    
    if not requested_stages:
        log("Error: No action specified.", Colors.YELLOW)
        parser.print_help()
        sys.exit(1)
    
    # Handle DUT (always required)
    if args.dut:
        variables['dut'] = args.dut
    else:
        log("Error: -dut is required", Colors.RED)
        sys.exit(1)
    
    variables = resolve_variables(variables)
    
    # Resolve dependencies
    final_execution_list = []
    seen_stages = set()
    
    for req_stage in requested_stages:
        deps = get_dependencies(req_stage, stages_config)
        for stage in deps:
            if stage not in seen_stages:
                final_execution_list.append(stage)
                seen_stages.add(stage)
    
    dut_name = variables.get('dut', 'unknown')
    flags_str = ' '.join([f"-{f}" for f in active_flags])
    
    # Print header
    log(f"{'─' * 40}", Colors.DIM)
    log(f"  {dut_name.upper()}  {flags_str}", bold=True)
    log(f"{'─' * 40}", Colors.DIM)
    
    # Run clean BEFORE initializing logger (it deletes the logs directory)
    if 'clean' in final_execution_list:
        run_stage('clean', stages_config, variables)
        final_execution_list.remove('clean')
    
    # Initialize build logger (after clean, so it doesn't get deleted)
    logs_dir = variables.get('logs_dir')
    BUILD_LOGGER = BuildLogger(logs_dir, timestamp)
    BUILD_LOGGER.start()
    
    # Log build info
    BUILD_LOGGER.write(f"DUT: {dut_name}\n")
    BUILD_LOGGER.write(f"Flags: {flags_str}\n")
    BUILD_LOGGER.write(f"Verbose: {VERBOSE}\n\n")
    BUILD_LOGGER.write(f"Stages to execute: {' -> '.join(final_execution_list)}\n\n")
    
    # Execute remaining stages
    for stage in final_execution_list:
        run_stage(stage, stages_config, variables)
    
    # Print success message before finishing log
    log(f"\n✓ Build successful", Colors.GREEN, bold=True)
    
    # Finish logging and get log file path
    log_path = BUILD_LOGGER.finish(success=True)
    
    # Print log file path (after logger is closed, just to console)
    print(f"{Colors.DIM}    → {log_path}{Colors.RESET}")

if __name__ == "__main__":
    main()
