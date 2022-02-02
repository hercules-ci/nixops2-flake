
# NixOps 2 example flake

Use this repository as a template for your own deployments. Or anything really, see [unlicense license](./LICENSE).

Remember to check your cloud provider's console when you're done or when things don't go according to plan, in case you accidentally leave something running and get billed for it.

# Status

NixOps2's flake feature currently only supports one configuration per flake.

This example repo will be updated when

# Getting Started

## Repo Prep (!)

Make sure you're on a branch that's set up to push to your GitHub repo. The `hci` command uses this info for context.

Make sure your GitHub repo has a Hercules CI installation. This provides storage for the NixOps state file and allows the CI to run.

## First Deployment

Configure your aws credentials in `~/.aws/credentials`

```ini
[nixops-example]
aws_access_key_id = AKIA.....
aws_secret_access_key = .....
```

Initialize the NixOps state file with 

```console
$ hci state put --name default.nixops --file /dev/null
$ nixops create -d default
```

Deploy with `nixops deploy`.

## First Hermetic Deployment

This section performs a local deployment, assuming you run Linux. If you don't, you can skip to the next section.

Similar to how Nix requires you to declare all build inputs, Hercules CI Effects require you to declare cloud credentials using _secrets_. We'll create these locally first.

```console
$ hci secret init-local
hci: Secrets file already existed. Path: /home/user/.config/hercules-ci/secrets/github/example-org/secrets.json

$ hci secret add nixops-example-aws --string aws_access_key_id AKIA..... --string aws_secret_access_key .....

```

NOTE: If you're getting `git` errors, make sure you've set an upstream for your branch with `git push -u`.

You can now run the deployment process on your local system.

```console
hci effect run --as-branch main effects.staging-hello.run 
```

## Continuous Integration and Cache

The `runIf` function modifies the effect to perform a pure build instead of a deployment, unless the condition (branch is `main`) is satisfied.

You can perform this build manually using `nix build .#checks.x86_64-linux.deploy-staging-hello-prebuilt`.

The CI will also build this configuration, to make sure your branches are deployable, and to make sure all packages are cached before deployment.

Create a feature branch and a PR to see these run on CI. See the [dashboard](https://hercules-ci.com/dashboard) or click the commit status details.

Known issue: the first build may take a while as Hercules CI processes the whole derivation tree. This will be optimized.

## Continuous Deployment

Make sure that your agents have the required secrets. Copy the relevant `Secret` objects into its `secrets.json`. A restart is not necessary.

You can copy them from the path showns by `hci secret init-local` (idempotent) or you can generate the JSON with help of the `hci secret echo` command, which is a simpler variation of the `add` command suggested in the "First Hermetic Deployment" section.

After you merge the PR in GitHub, click the merge commit and then click the status icon left of the commit title to navigate to the dashboard.

# Remove the Cloud Resources

Run `nixops destroy` to remove the virtual machines and other created resources.

# Adapt to your needs

## Rename

This example (mainly) uses the name `nixops-example` for the deployment name.

The secret is named `nixops-example-aws` because the convention is `${deployment}-${service}`.

## Test or Staging Environment

NixOps currently only supports `nixopsConfigurations.default`, limiting the options when it comes to staging. You might be able to work around this limitation by using a diverging git branch, although I would generally not recommend that. This example will be updated when multiple `nixopsConfigurations` is implemented in NixOps. FIXME: issue link to subscribe

## Other Cloud Provider

You can use the `userSetupScript` attribute to install credentials for any cloud provider.

See [readSecretString](https://docs.hercules-ci.com/hercules-ci-effects/reference/bash-functions/readsecretstring/) and related functions.

## No Cloud Provider

If you want to deploy to existing machines, use the commented code to use an `ssh` key instead of the AWS stuff.

## HTTPS

The example is a webserver. I've kept the configuration overly simple. You could change it to use Let's Encrypt with only a couple of options. Also check out the `services.nginx.recommended*` settings.
