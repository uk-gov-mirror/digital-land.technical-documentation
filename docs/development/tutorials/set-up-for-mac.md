---
title: Setting up a Mac for use on our project
---

This tutorial aims to walk you through a lot of the base level requirements you need to work on the majority of our code base. Our codebase spans a lot and this attempts to just install the essential parts that are generally needed. There may be app specific requirements on top of this but this is a good place to start when joining the project.

This is aimed at beginners so may be more detailed than needed for experienced devs. It can still act as a list of things to get set up. Our How-to guides might be more useful to install the bits that you need.

It's worth noting that a `setup.sh` script has been added to `scripts/setup.py` which installs all the following software on a Mac but this tutorial still exists to justify and explain what it does.

Contents:


* Install Homebrew 
* Install Rosetta 2
* Set up SSH for Github
* Recommended git configuration
* Install sqlite3 and build dependencies
* Install geospatial tools
* Install Make

* Install Python (and understand venvs)
* Install Oh My Zsh
* Install fnm and Node
* Optional but recommended setup

* Creating .zshrc and .zprofile files



### Install Homebrew

When installing the majority of software on a Mac, Homebrew is a very nice to use piece of software. For Mac it mimics the capability of package managers in Linux allowing us to easily install software on the command line. 

It has some limitations when it comes to the versions of certain software and there may be better programs out there to use. This is worth keeping in mind and perhaps updating the parts of this guide that use brew in the future. For now it is usable and gets us what we need.

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installing Homebrew it should be updated

```sh
brew update
```

### Install Rosetta 2

To install rosetta 2 you can run

```
softwareupdate --install-rosetta --agree-to-license
```

Rosetta 2 is required because mainly as a dependency for docker because Apple Silicon Macs (M1/M2/M3/M4) use ARM-based chips, but many Docker images are still built for Intel/AMD (x86_64) processors. Rosetta 2 translates those x86 instructions so they can run efficiently on ARM hardware.

Docker Desktop uses Rosetta to run amd64 container images significantly faster than its default emulation method. Without it, x86 images still work, but run slower and can occasionally behave unreliably.

In short: install Rosetta 2 so Docker can run x86/Intel-based container images quickly and reliably on your Apple Silicon Mac.

### Set up SSH for Github

Our code base is all contained within Github and is publicly available. If you want to start downloading and looking at the code without pushing any changes then you won't need to set this up.

When making changes to code if you've downloaded via https it will require you to enter your Github user details each time. While this is doable it can slow development down so we advise using ssh when working on our code base to make changes to Github repositories.

> **If these instructions become outdated**, GitHub's official guide is the authoritative fallback: [Generating a new SSH key and adding it to the ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

#### Check that you have git installed

On Mac this generally comes bundled with Xcode. It may already be installed but often it may not be, or an update may have caused it to be removed.

You can check if git is installed by checking the version:

```sh
git --version
```

If you get a version number then git is installed:

```sh
git version 2.39.1
```

However you may get an error like the following:

```sh
xcrun: error: invalid active developer path (/Library/Developer/CommandLineTools), missing xcrun at: /Library/Developer/CommandLineTools/usr/bin/xcrun
```

If this appears you can install Xcode Command Line Tools by running:

```sh
xcode-select --install
```

A window will pop up and guide you through the installation.

#### Create a Github account and have it added to the digital land organisation

Before we do anything you need to have a Github account to add the SSH key to. Github accounts are free and you can set this up yourself.

You're welcome to use a Github account that you already have, but you **must** remove any personal access tokens first.

Otherwise we suggest creating an account with the communities email address provided to you.

Once it's created, reach out to the infrastructure team who can get you added to the organisation with the correct privileges. It will be good to include the team lead from the team you're joining in this message so any questions can be asked and answered by them.

#### Generate an SSH key

Run the following command, replacing the email with the one on your Github account:

```sh
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519 -N ""
```

This generates a modern ed25519 key and saves it to `~/.ssh/id_ed25519`. The `-N ""` flag sets an empty passphrase — the next step configures macOS Keychain to handle authentication instead, so you won't be prompted each time.

#### Start the SSH agent

The SSH agent holds your key in memory so other tools can use it without you needing to re-enter credentials. Start it with:

```sh
eval "$(ssh-agent -s)"
```

#### Configure ~/.ssh/config for macOS Keychain persistence

This is a Mac-specific step. Without it, the key would need to be re-added to the agent every time you restart your computer.

Create or open `~/.ssh/config` and add the following block:

```
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
```

You can append it from the terminal by running:

```sh
cat >> ~/.ssh/config << 'EOF'

Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
```

What each line does:

* `AddKeysToAgent yes` — automatically loads the key into the agent the first time it is used
* `UseKeychain yes` — stores the passphrase in macOS Keychain so the key survives restarts
* `IdentityFile` — tells SSH which key file to use when connecting to GitHub

#### Add the key to the SSH agent

```sh
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

The `--apple-use-keychain` flag stores the key in macOS Keychain as well as loading it into the agent, so you won't need to repeat this step after a restart.

#### Add your SSH key to your Github account

Copy your public key to the clipboard:

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

Then add it to Github:

1. Go to [https://github.com/settings/keys](https://github.com/settings/keys)
2. Click **New SSH key**
3. Give it a name so you can identify which computer it's from
4. Leave the key type as **Authentication Key**
5. Paste the key with Cmd+V
6. Click **Add SSH key**

#### Test the connection

Verify that everything is working:

```sh
ssh -T git@github.com
```

You should see a message like:

```
Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

You're all set. Clone a repository using SSH to confirm end-to-end.

### Recommended Git configuration

With git installed it's worth setting a couple of global defaults that match how we work.

Set the default branch name to `main` (git still defaults to `master` without this):

```sh
git config --global init.defaultBranch main
```

Set the push default to `current`, which pushes the current branch to a branch of the same name on the remote without needing to specify it explicitly:

```sh
git config --global push.default current
```

These are written to `~/.gitconfig` and apply to every repository on your machine.

### Install sqlite3 and build dependencies

Before installing Python we need to install sqlite3 and a handful of other libraries that Python is compiled against. Installing them first means the Python build picks them all up correctly — if you install Python first you may end up with a build that is missing features (most commonly sqlite3 loadable extension support, which is required for SpatiaLite).

Install everything in one go:

```sh
brew install sqlite xz openssl readline zlib tcl-tk libpq
```

What each package is for:

* **sqlite** — macOS ships with sqlite but it doesn't allow loadable extensions. We use SpatiaLite (a geospatial extension) in several repos, so we need the Homebrew version which does.
* **xz** — provides lzma compression, required for Python's `lzma` module.
* **openssl** — required for Python's `ssl` module and for pip to fetch packages over https.
* **readline** — provides command-line editing in Python's interactive shell.
* **zlib** — compression library required for Python's `zlib` module.
* **tcl-tk** — required if you ever need Python's `tkinter` GUI module.
* **libpq** — PostgreSQL client library required for compiling `psycopg2`, which is used in repos that talk to a PostgreSQL database.

After installing, the Homebrew-managed sqlite3 needs to be on your PATH ahead of the macOS system version. The `setup.sh` script handles this by writing the following to `~/.zprofile`:

```sh
export PATH="/opt/homebrew/opt/sqlite/bin:$PATH"
```

If you are following this guide manually, add that line to your `~/.zprofile` (or `~/.zshrc`).

> **Install these before Python.** The Python build reads these libraries at compile time. Installing Python first and adding the libraries later will produce a Python build that is missing the corresponding modules.


### Install geospatial tools

GDAL is a set of libraries and command-line tools for reading, writing, and processing geospatial data. It is used across our pipelines and in the main application. SpatiaLite is a geospatial extension for SQLite and is the reason we installed the Homebrew version of sqlite3 earlier.

```sh
brew install gdal spatialite-tools
```

No additional shell configuration is needed — both install their binaries into `/opt/homebrew/bin`, which is already on your `PATH` via the Homebrew setup in `.zprofile`.

### Install Make

Make is used through our code base to quickly and easily run data processing tasks or set up application specific environments. Macs come with version 3.81 of make already installed however we need more recent versions above 4.x.x. There's a mixture of reasons Apple does this (licensing, backwards compatibility, etc.).

To install make we can use brew:

```
brew install make
```

Because there is already a version of make on your computer this version of make is available under gmake instead. You can see this by comparing the versions of make and gmake

```
make --version
```

and 

```
gmake --version
```

In our scripts we generally only call `make` so this can be problematic. To put the Homebrew version on your PATH ahead of the system one, add the following to your `~/.zprofile`:

```sh
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
```

The `setup.sh` script handles this automatically.


### Install Python

The majority of our code base is Python. We recommend installing Python using pyenv (Option A below), which lets you manage multiple versions and switch between them automatically per project. If you prefer to manage versions yourself, Option B covers the Homebrew approach.

> **Install sqlite3 and the build dependencies first** (see the section above). Python is compiled from source by pyenv and needs those libraries to be present at build time.

#### Option A: pyenv (recommended)

pyenv installs and manages multiple Python versions side by side. Each project can pin a specific version via a `.python-version` file in its root, and pyenv switches automatically when you `cd` into that directory.

Install pyenv:

```sh
brew install pyenv
```

Add the following to your `~/.zshrc` so pyenv is available in every terminal session:

```sh
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
```

The `setup.sh` script adds these lines automatically. If you're following this guide manually, reload your shell after adding them:

```sh
source ~/.zshrc
```

Now install the Python versions used across our repos:

```sh
pyenv install 3.9.19
pyenv install 3.11.9
pyenv install 3.13.3
```

These take a few minutes each — pyenv compiles Python from source so it picks up the build dependencies you installed earlier, including sqlite3 loadable extension support.

Set the global default to the latest version:

```sh
pyenv global 3.13.3
```

Verify it is active:

```sh
python --version
```

To pin a specific Python version for a project, add a `.python-version` file to the repo root:

```sh
echo "3.9.19" > .python-version
```

pyenv will switch to that version automatically whenever you `cd` into that directory.

#### Option B: Homebrew

Homebrew can install Python versions directly. This is simpler but you'll need to reference versions explicitly by number (`python3.9`, `python3.11`) rather than relying on automatic switching.

```sh
brew install python@3.9
brew install python@3.11
brew install python@3.13
```

Verify an installation:

```sh
python3.9 --version
```

> Tip: If you installed Python before installing the sqlite3 build dependencies, uninstall and reinstall it — for example `brew uninstall python@3.9 && brew install python@3.9` — so it picks up the correct libraries.

### Virtual environments

Every Python repo in our codebase uses a virtual environment to isolate its dependencies. See the [Python virtual environments tutorial](/development/tutorials/python-virtual-environments/) for a full walkthrough.

To make day-to-day venv work faster, add these aliases to your `~/.zshrc`:

```sh
alias mkvenv='python -m venv .venv && source .venv/bin/activate'
alias workon='source .venv/bin/activate'
```

The `setup.sh` script adds these automatically. With them in place:

* `mkvenv` — creates a `.venv` in the current directory using the active Python version and immediately activates it
* `workon` — activates an existing `.venv` in the current directory, useful at the start of each terminal session


### Install Oh My Zsh

Oh My Zsh is a framework for managing your zsh configuration. It provides a plugin system, theme support, and a large collection of useful aliases and helpers out of the box. It sits on top of zsh (which is already the default shell on macOS) and makes the terminal noticeably more pleasant to work in.

To install it:

```sh
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

The two environment variables prevent the installer from doing things that would interrupt the setup script:

* `RUNZSH=no` — don't launch a new zsh session immediately after installing
* `CHSH=no` — don't try to change the default shell (zsh is already the default on macOS)

Once installed, Oh My Zsh manages your `~/.zshrc`. You can change the theme by editing `~/.zshrc` and updating the `ZSH_THEME` value. A popular optional theme is [Powerlevel10k](https://github.com/romkatv/powerlevel10k), which shows git status, Python version, and other context directly in your prompt.

### Install fnm and Node

fnm (Fast Node Manager) is to Node what pyenv is to Python — it lets you install multiple Node versions and switch between them automatically per project using an `.nvmrc` file in the repo root.

Not all of our repos use Node, but enough do that it's worth installing upfront.

Install fnm:

```sh
brew install fnm
```

Then install the latest Node LTS version and set it as the default:

```sh
fnm install --lts
fnm default $(fnm list-remote --lts | tail -1)
```

Add the following to your `~/.zshrc` so fnm is active in every terminal session and switches Node version automatically when you `cd` into a project:

```sh
eval "$(fnm env --use-on-cd --version-file-strategy=recursive --resolve-engines)"
```

The `setup.sh` script adds this line automatically. What the flags do:

* `--use-on-cd` — switches Node version automatically when you change into a directory that has an `.nvmrc` file
* `--version-file-strategy=recursive` — looks up parent directories for an `.nvmrc` if none is found in the current directory
* `--resolve-engines` — also respects the `engines.node` field in `package.json`

## Optional but recommended setup for your Mac

The steps above will get you up and running. The things below are not strictly required but will make day-to-day development noticeably more pleasant.

### Apps

The `setup.sh` script offers to install the following apps during setup. You can also install any of them individually at any time using Homebrew.

#### Google Chrome

```sh
brew install --cask google-chrome
```

A reliable browser for day-to-day work and testing. Most of the team uses it as their primary browser.

#### Slack

```sh
brew install --cask slack
```

Our main team communication tool. You will need this to be added to the digital-land workspace.

#### Ghostty

```sh
brew install --cask ghostty
```

A fast, modern terminal emulator. A good alternative to the default macOS Terminal if you want something more capable. Entirely optional — use whatever terminal you are comfortable with.

#### Visual Studio Code

```sh
brew install --cask visual-studio-code
```

A free code editor that works well with our Python and JavaScript codebases. Once installed, open any project folder directly from the terminal with:

```sh
code .
```

##### VS Code extensions

The following extensions are worth installing. Search for them by name in the Extensions panel (the blocks icon in the left sidebar), or install them from the terminal using the `code` command.

**Python**

* **Python** (`ms-python.python`) — syntax highlighting, linting integration, and virtual environment support
* **Pylance** (`ms-python.vscode-pylance`) — improved type checking and autocomplete for Python
* **Black Formatter** (`ms-python.black-formatter`) — auto-formats Python files on save using Black, which is our standard formatter

**JavaScript / Node.js**

* **ESLint** (`dbaeumer.vscode-eslint`) — highlights linting errors in JavaScript and TypeScript files
* **Prettier** (`esbenp.prettier-vscode`) — auto-formats JavaScript, CSS, and other frontend files on save
* **npm IntelliSense** (`christian-kohler.npm-intellisense`) — autocompletes npm package names in import statements

**General**

* **GitLens** (`eamodio.gitlens`) — shows git blame inline and makes it easier to explore history
* **Code Spell Checker** (`streetsidesoftware.code-spell-checker`) — catches typos in code and comments

**Docker**

* **Docker** (`ms-azuretools.vscode-docker`) — manage containers and images from within VS Code

#### Docker

```sh
brew install --cask docker
```

Docker Desktop lets you run containerised services locally. Several of our repos depend on it for local development (databases, background workers, etc.) and for running tests with tools such as Testcontainers.

After installing, open Docker Desktop from your Applications folder and complete the initial setup. Once it has started, verify the command line tools are available:

```sh
docker --version
docker compose version
```

You can also run a quick smoke test:

```sh
docker run hello-world
```

If that succeeds, Docker is ready. Note that Docker Desktop must be running in the background whenever you use commands like `docker build`, `docker compose up`, or any tests that start containers — it does not start automatically on login unless you enable that in its settings.

## General guidance

The sections below are general tips that apply once you are up and running. They will likely move to a more permanent home in the docs at some point.

### Pre-commit hooks

Several of our repositories use pre-commit hooks to automatically check code formatting and style before each commit. This catches issues like Black formatting violations locally, rather than having CI fail on them minutes later.

After cloning any repository, check whether it has a `.pre-commit-config.yaml` file in the root. If it does, activate your virtual environment and then run:

```sh
pre-commit install
```

You only need to do this once per repo. After that, the checks will run automatically every time you `git commit`. Some repos also have a `make init` command that does this for you alongside other setup steps — check the `Makefile` or `README` when setting up a new repo.

### Spatialite-tools

Running tests in some of our repositories requires spatialite-tools:

```sh
brew install spatialite-tools
```

### Cloning repos as sibling directories

Our codebase spans multiple repositories that sometimes depend on each other or are worked on together. It helps to keep them all cloned into the same parent folder so they sit alongside each other as siblings, rather than scattered around your machine. For example:

```
code/
├── digital-land-python/
├── airflow-dags/
├── collection-task/
├── async-request-backend/
└── config/
```

This makes it easier to navigate between them in the terminal and in your editor, and some scripts assume a layout like this.

Pick a parent folder name that works for you and clone each repository into it using SSH (see the SSH setup section above):

```sh
git clone git@github.com:digital-land/<repo-name>.git
```

### Editing shell config files (.zshrc and .zprofile)

Throughout this guide you are asked to add lines to `~/.zshrc` and `~/.zprofile`. Both are hidden files (the `.` prefix) so they won't show up in Finder. There are two straightforward ways to edit them.

Open the file in a GUI text editor:

```sh
open -e ~/.zshrc
```

Or append a line directly from the terminal:

```sh
echo 'export MY_VAR="value"' >> ~/.zshrc
```

After making any change, either open a new terminal window or reload the file in the current session:

```sh
source ~/.zshrc
```