# New project

## 作成

```bash
new-project ExampleProject --github
cd ~/src/ExampleProject
setup-workspace
```

`setup-workspace`はproject名から次のlinkを自動作成します。

```text
workspace/research-inout  -> Research/aicode/inout/ExampleProject
workspace/research-output -> Research/aicode/output/ExampleProject
workspace/large-input     -> ForShareLargeData/aicode/input/ExampleProject
workspace/large-output    -> ForShareLargeData/aicode/output/ExampleProject
workspace/scratch         -> local ~/scratch/...
```

projectごとに任意のDropbox pathを設定する必要はありません。必要なdataや資料を対応するproject directoryへコピーし、その内部にsubdirectoryを作ります。

## 用途

- `research-inout`: 文書、metadata、manifest、小さな入力、共有staging
- `research-output`: report、table、figure、通常サイズのoutput
- `large-input`: 大容量入力。原則read-only
- `large-output`: 大容量output
- `scratch`: localの再生成可能なtemporary file

複数taskやrunが同時進行する場合は、output内にtask名やrun名のsubdirectoryを作ります。

```text
workspace/research-output/metadata-audit/
workspace/large-output/integration-v1/
```

## Agent起動

```bash
code .
```

Agentはrepository内と5つのworkspace pathだけを使用し、Dropbox rootや他projectを探索しません。
