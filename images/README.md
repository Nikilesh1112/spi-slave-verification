# images/

This folder is for waveform screenshots and diagram exports you add
after running the testbench (e.g. an EPWave or GTKWave screenshot
showing a passing smoke_test, or a coverage report screenshot).

Suggested additions once you've run the tests yourself:
- `smoke_test_waveform.png` - a screenshot of the smoke test waveform
- `coverage_report.png` - a screenshot of the final coverage summary
- `architecture_diagram.png` - an exported version of the ASCII
  diagram in `docs/architecture.md`, if you'd like a nicer visual for
  the README

Reference them in the main `README.md` with standard Markdown image
syntax once added, e.g.:

```markdown
![Smoke test waveform](images/smoke_test_waveform.png)
```
