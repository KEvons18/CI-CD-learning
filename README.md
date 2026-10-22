CI-CD-learning

A small learning project that walks through Docker and a CI/CD pipeline with GitHub Actions, built entirely inside a GitHub Codespace.

What the pipeline does:

You push code to main.
GitHub Actions builds the Docker image.
It runs a quick test against the running container.
If the test passes, it publishes the image to GitHub Container Registry (ghcr.io).
Table of contents
Project structure
Docker basics
Create the Dockerfile
Build and run locally
CI: build and test with GitHub Actions
Break it on purpose
CD: publish to GitHub Container Registry
Pull and run the published image
Troubleshooting
Next steps
Project structure
CI-CD-learning/
├── .github/
│   └── workflows/
│       └── docker-build.yml   # the CI/CD pipeline
├── Dockerfile                 # how to build the image
└── README.md
1. Docker basics

Docker comes preinstalled in GitHub Codespaces. Check that it works:

bash
docker --version
docker run hello-world
Common commands

Images

bash
docker pull nginx         # download an image from Docker Hub
docker images             # list local images
docker rmi nginx          # remove an image
docker build -t myapp .   # build an image from a Dockerfile in the current folder

Containers

bash
docker run -d -p 8080:80 nginx         # run in background, map host port 8080 -> container port 80
docker run -it ubuntu bash             # interactive shell inside a container
docker ps                              # list running containers
docker ps -a                           # list all containers, including stopped ones
docker stop container_id               # stop a container
docker start container_id              # start a stopped container
docker rm container_id                 # delete a container
docker logs container_id               # view a container's output
docker exec -it container_id bash      # open a shell in a running container

Note: replace container_id with the real ID or name from docker ps. Do not type angle brackets (< >); bash treats them as redirection and throws a syntax error.

Tip: give containers names so you never have to hunt for IDs:

bash
docker run -d --name hello-site -p 8080:80 my-first-image
docker stop hello-site
docker rm hello-site

Cleanup

bash
docker container prune    # remove all stopped containers
docker system prune       # remove stopped containers, unused networks, dangling images

Docker Compose (for multi-container apps)

bash
docker compose up -d
docker compose down
2. Create the Dockerfile

A Dockerfile is a plain text file named exactly Dockerfile (capital D, no extension) in the repo root.

bash
touch Dockerfile
code Dockerfile

Contents:

dockerfile
FROM nginx
RUN echo "Hello from my CI/CD repo" > /usr/share/nginx/html/index.html
FROM nginx starts from the official nginx image.
RUN echo ... runs during the build and replaces the default web page with custom text.
3. Build and run locally
bash
docker build -t my-first-image .
docker run -d -p 8080:80 my-first-image
curl localhost:8080

The . at the end of the build command means "use the current folder". The curl command should print Hello from my CI/CD repo.

In a Codespace you can also open the Ports tab and click the forwarded address for port 8080.

4. CI: build and test with GitHub Actions

Workflows live in .github/workflows/. The folder path must be exact or GitHub will not detect them.

bash
mkdir -p .github/workflows
touch .github/workflows/docker-build.yml
code .github/workflows/docker-build.yml

First version (CI only):

yaml
name: Docker Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Check out the code
        uses: actions/checkout@v4

      - name: Build the Docker image
        run: docker build -t my-first-image .

      - name: Test the container
        run: |
          docker run -d --name test-site -p 8080:80 my-first-image
          sleep 3
          curl --fail localhost:8080 | grep "Hello from my CI/CD repo"

Commit and push:

bash
git add .github Dockerfile
git commit -m "Add Docker build workflow"
git push

Then open the repo on GitHub, go to the Actions tab, and click the latest run. A green check means it passed; a red X means something failed and the logs will show why.

What each part does
Part	Purpose
on:	The trigger: pushes to main and pull requests targeting main
runs-on: ubuntu-latest	GitHub starts a fresh Linux machine for the job
actions/checkout@v4	Downloads the repo's code onto that machine
run: steps	The same shell commands you would type by hand
curl --fail ... | grep	A mini test: if the page does not contain the expected text, the step fails
5. Break it on purpose

The best way to see CI working:

Edit the Dockerfile so the text says something different (for example "Goodbye").
Commit and push.
The Test the container step fails and the run shows a red X.
Open the failed run and read the logs to see why.
Change the text back, commit, and push. The run goes green again.

Reading failed logs is a core CI/CD skill.

6. CD: publish to GitHub Container Registry

GitHub has a built-in container registry (ghcr.io). No extra account or secret is needed because every workflow run gets an automatic GITHUB_TOKEN.

Replace the contents of .github/workflows/docker-build.yml with:

yaml
name: Docker Build and Push

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Check out the code
        uses: actions/checkout@v4

      - name: Build the Docker image
        run: docker build -t my-first-image .

      - name: Test the container
        run: |
          docker run -d --name test-site -p 8080:80 my-first-image
          sleep 3
          curl --fail localhost:8080 | grep "Hello from my CI/CD repo"

      - name: Log in to GitHub Container Registry
        if: github.event_name == 'push'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Tag the image
        if: github.event_name == 'push'
        run: |
          IMAGE=$(echo "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}" | tr '[:upper:]' '[:lower:]')
          docker tag my-first-image $IMAGE:latest
          docker tag my-first-image $IMAGE:${{ github.sha }}

      - name: Push the image
        if: github.event_name == 'push'
        run: |
          IMAGE=$(echo "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}" | tr '[:upper:]' '[:lower:]')
          docker push $IMAGE:latest
          docker push $IMAGE:${{ github.sha }}

Commit and push:

bash
git add .github
git commit -m "Push image to GHCR"
git push
What changed and why
permissions: packages: write lets the automatic token upload to the registry. Without it the push fails with a "denied" error.
env: defines the registry and image name once. github.repository expands to KEvons18/CI-CD-learning.
if: github.event_name == 'push' limits login, tag, and push to real pushes to main. Pull requests are still built and tested, but nothing is published from unreviewed code.
tr '[:upper:]' '[:lower:]' lowercases the image name, because Docker image names must be lowercase.
Two tags per image: latest (always the newest) and the commit SHA (a permanent label for that exact version, useful for rollbacks).
7. Pull and run the published image

Find the image in the repo's right sidebar under Packages, or on your GitHub profile under the Packages tab.

Pull it:

bash
docker pull ghcr.io/kevons18/ci-cd-learning:latest

If the package is private, log in first with a Personal Access Token (classic) that has the read:packages scope:

bash
echo YOUR_TOKEN | docker login ghcr.io -u KEvons18 --password-stdin

Or make it public: open the package page, go to Package settings, and change visibility to Public.

Run it to prove it is the same image the pipeline built:

bash
docker run -d --name from-registry -p 8082:80 ghcr.io/kevons18/ci-cd-learning:latest
curl localhost:8082

# clean up
docker stop from-registry
docker rm from-registry
Troubleshooting
Problem	Cause and fix
Bind for 0.0.0.0:8080 failed: port is already allocated	Another container is using that port. Run docker ps, then docker stop container_id, or use a different host port like -p 8081:80.
Failed container left in "Created" state	Remove it with docker rm container_name or docker container prune.
bash: syntax error near unexpected token 'newline'	You typed the angle brackets from <container_id>. Use the bare ID instead.
denied: permission_denied on push	The permissions: block is missing or misindented in the workflow. Also check Package settings → Manage Actions access.
invalid reference format	The image name contains capital letters. Lowercase it.
Workflow does not appear in the Actions tab	The file is not in exactly .github/workflows/ or is not valid YAML.
Next steps
Deploy it: use a platform like Render or Fly.io to pull the image from ghcr.io and run it at a public URL.
Self-host it: run it on a small VPS and have the workflow SSH in to pull and restart the container.
Make the app real: replace the static page with a small Node or Python app and add real unit tests so CI has something meaningful to check.
What I learned
Docker packages an app and everything it needs into an image that runs the same anywhere.
CI (Continuous Integration) automatically builds and tests every change.
CD (Continuous Delivery) automatically publishes the tested result somewhere it can be deployed.
A failing pipeline is useful: it catches mistakes before they reach users.
