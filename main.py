"""
SuperNjagu Agent - Main Entry Point
High-Performance Autonomous AI Agent
"""

import asyncio
import sys
from src.agent import SuperNjaguAgent
from tools.file_operations import FileOperations
from tools.web_operations import WebOperations
from tools.cli_operations import CLIOperations
from tools.data_operations import DataOperations


class SuperNjaguMain:
    """Main orchestrator for SuperNjagu Agent"""
    
    def __init__(self, workspace: str = "/workspace"):
        self.workspace = workspace
        self.agent = SuperNjaguAgent(workspace)
        self.file_ops = FileOperations(workspace)
        self.web_ops = WebOperations()
        self.cli_ops = CLIOperations(workspace)
        self.data_ops = DataOperations()
    
    async def run_task(self, task_description: str) -> dict:
        """Run a task autonomously"""
        print(f"\n🚀 SuperNjagu Agent - Starting Task")
        print(f"📋 Task: {task_description}")
        print(f"🏢 Workspace: {self.workspace}")
        print("-" * 60)
        
        result = await self.agent.execute_autonomous(task_description)
        
        print("-" * 60)
        print(f"✅ Task Status: {result['status']}")
        print(f"📊 Steps Completed: {len(result['steps'])}")
        
        return result
    
    def get_status(self) -> dict:
        """Get agent status"""
        return self.agent.get_status()
    
    def interactive_mode(self):
        """Run in interactive mode"""
        print("\n🤖 SuperNjagu Agent - Interactive Mode")
        print("Type 'help' for commands, 'exit' to quit")
        print("-" * 60)
        
        while True:
            try:
                user_input = input("\n🎯 SuperNjagu> ").strip()
                
                if not user_input:
                    continue
                
                if user_input.lower() == 'exit':
                    print("👋 Goodbye!")
                    break
                
                elif user_input.lower() == 'help':
                    self._show_help()
                
                elif user_input.lower() == 'status':
                    status = self.get_status()
                    print(f"\n📊 Agent Status:")
                    for key, value in status.items():
                        print(f"  {key}: {value}")
                
                elif user_input.lower().startswith('create '):
                    _, content = user_input.split(' ', 1)
                    result = self.file_ops.create_file("user_file.txt", content)
                    print(f"\n✅ {result}")
                
                elif user_input.lower().startswith('read '):
                    _, filename = user_input.split(' ', 1)
                    result = self.file_ops.read_file(filename)
                    print(f"\n📖 {result}")
                
                elif user_input.lower().startswith('run '):
                    _, command = user_input.split(' ', 1)
                    result = self.cli_ops.execute_command(command)
                    print(f"\n⚡ Command Result:")
                    print(f"  Success: {result['success']}")
                    if result.get('stdout'):
                        print(f"  Output: {result['stdout'][:200]}...")
                
                else:
                    # Run as autonomous task
                    result = asyncio.run(self.run_task(user_input))
                    print(f"\n✨ Result: {result['final_result']}")
            
            except KeyboardInterrupt:
                print("\n\n👋 Interrupted. Type 'exit' to quit.")
            except Exception as e:
                print(f"\n❌ Error: {str(e)}")
    
    def _show_help(self):
        """Show help information"""
        help_text = """
📚 SuperNjagu Agent Commands:

🤖 Autonomous Tasks:
  Any text input is treated as a task to be executed autonomously
  Example: "Create a Python web scraper for news"

📁 File Operations:
  create <content>     - Create a file with content
  read <filename>      - Read file contents

⚡ CLI Operations:
  run <command>        - Execute shell command

ℹ️  System Commands:
  status               - Show agent status
  help                 - Show this help
  exit                 - Exit the agent

💡 Tip: The agent will autonomously break down complex tasks,
     execute them step by step, and report progress!
"""
        print(help_text)


async def main():
    """Main entry point"""
    # Check command line arguments
    if len(sys.argv) > 1:
        task = " ".join(sys.argv[1:])
        super_njagu = SuperNjaguMain()
        await super_njagu.run_task(task)
    else:
        # Run in interactive mode
        super_njagu = SuperNjaguMain()
        super_njagu.interactive_mode()


if __name__ == "__main__":
    asyncio.run(main())