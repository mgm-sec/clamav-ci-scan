# ClamAV in CI

Malware scanning with ClamAV for repos that build and push a Docker image to GHCR.

Three scans:

1. **Repository**: every PR and push. Catches files that never end up in the image too.
2. **Image**: after the build, before the push. An infected image is never pushed.
3. **Weekly rescan**: published images (`main` and the latest `v*` tag) with fresh signatures.

Each scan fails the job when something is found.

## Add it to a repo

1. Copy `.github/clamav-scan.sh` and `.github/workflows/clamav-rescan.yml` as they are.

2. Add a job to `ci.yaml`:

   ```yaml
     malware_scan:
       name: Scan repository for malware (ClamAV)
       runs-on: ubuntu-24.04
       permissions:
         contents: read
       steps:
         - name: Checkout repository
           uses: actions/checkout@v7

         - name: Scan repository for malware (ClamAV)
           run: tar -cf - --exclude=./.git . | bash .github/clamav-scan.sh
   ```

3. Add a step to the image job, directly before `Push Docker image`:

   ```yaml
         - name: Scan image for malware (ClamAV)
           env:
             IMAGE: ${{ fromJSON(steps.meta.outputs.json).tags[0] }}
           run: docker export "$(docker create "$IMAGE")" | bash .github/clamav-scan.sh
   ```

   The image must be built with `load: true`.

4. If the image job uses `tj-actions/changed-files`, add `.github/clamav-scan.sh` to its file list.

See `.github/workflows/ci.yaml` for a complete example.

## How it works

`clamav-scan.sh` reads a tar stream, unpacks it in a `clamav/clamav` container and runs `clamscan` on it. The image is scanned as a flat filesystem (`docker export`), so base image, OS packages, Python packages and app code are all covered. Archives (zip, tar.gz, nested) are opened.

Before each scan, `freshclam` fetches the latest signatures. If that fails (GitHub runners sometimes get rate limited), the scan continues with the signatures in the image and the run shows a warning. Those are usually a few days old.

Files larger than 500 MB fail the scan instead of being skipped silently.

Exit codes: `0` clean, `1` malware found, `2` error.

## Testing

`self-test.yml` runs on every PR and push. It checks that EICAR is caught in the image (plain file, zip, zip inside a tar.gz) and in the repo. It also checks the fallback when `freshclam` fails, and that clean input passes.

To test the weekly rescan:

```sh
gh workflow run test-push-infected.yml           # pushes :eicar-test without scanning
gh workflow run clamav-rescan.yml -f tags="main eicar-test"
```

The rescan should fail on `eicar-test` and still scan `main`.

No EICAR file is stored in this repo. The tests decode it from base64 at runtime.

## Good to know

- Dependabot does not update `clamav/clamav:1.5.4-debian`, because it sits in a shell script. Bump it by hand.
- A failed scheduled run notifies the person who last changed the cron line, not a team.
- GitHub disables scheduled workflows in public repos after 60 days without activity.
- Trivy looks for known vulnerabilities, not malware. You need both.
- A scan adds about 45 seconds per job.
