Code rules

- this script runs in console UI style (ncurses style, using mostly whiptail), for user-interactive parts of code, reuse existing helper functions for prompts and menus
- for operation feedback, use functions lik ohai or msgok 
- do not change install.sh file - it is generated from src/lib.sh and src/setup.sh with npm run build command
- when generating code with command that may output to console, make sure to use convention to add >> "$LOGTO" 2>&1 to capture it into logs and not break UI

GIT Conventions

- make short (2-3 sentences) description for commit messages
- DO NOT MENTION claude code in commit messages

Agent and tooling rules:
- do not commit or run build unless asked by user
