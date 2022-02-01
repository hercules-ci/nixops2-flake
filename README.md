
# NixOps 2 example flake

Use this repository as a template for your own deployments. Or anything really, see [unlicense license](./LICENSE).

# Getting Started

## Repo prep

Make sure you're on a branch that's set up to push to your GitHub repo. The `hci` command uses this info for context.

Make sure your GitHub repo has a Hercules CI installation. This provides storage for the NixOps state file and allows the CI to run.

## Adapt to your needs

Open `flake.nix` to review `userSetupScript`, which reads credentials from Hercules CI secrets.

Start the project shell using `nix develop`.

Save the values for those secrets using the `hci secret add` command, which saves them to an organization-specific file in `~/.config/hercules-ci/secrets/`.

## First deployment

Initialize the NixOps state file with `nixops create -d default`.

Iterate with `nixops deploy`.

Test the deployment effect locally using

```
hci effect run --as-branch main effects.staging-hello.run
```

Copy the secrets from `~/.config/hercules-ci/secrets/` to your agents' `secrets.json`.

If you don't use `main` as your deployment branch, adapt the `runIf` line and `devShell` greeting.

Create a pull request to your deployment branch. Branches other than `main` will build the network without access to the actual deployment.

Merge the pull request. Click the merge commit status and then **Details** to open the deployment job in the dashboard.
