{
  name = "Diff",
  fileTypes = { "diff", "patch" },
  firstLineMatch = [[(?x)^\n\t\t(===\\ modified\\ file\n\t\t|==== \s* // .+ \s - \s .+ \s+ ====\n\t\t|Index:\ \n\t\t|---\ [^%]\n\t\t|\*\*\*.*\d{4}\s*$\n\t\t|\d+(,\d+)* (a|d|c) \d+(,\d+)* $\n\t\t|diff\\ --git\\ \n\t\t)\n\t]],
  foldingStartMarker = [[^\+\+\+]],
  foldingStopMarker = "^---|^$",
  keyEquivalent = "^~D",
  patterns = {
    {
      name = "meta.separator.diff",
      match = [[^((\*{15})|(={67})|(-{3}))$\n?]],
      captures = {
        [1] = { name = "punctuation.definition.separator.diff" },
      },
    },
    {
      name = "meta.diff.range.normal",
      match = [[^\d+(,\d+)*(a|d|c)\d+(,\d+)*$\n?]],
    },
    {
      name = "meta.diff.range.unified",
      match = [[^(@@)\s*(.+?)\s*(@@)($\n?)?]],
      captures = {
        [1] = { name = "punctuation.definition.range.diff" },
        [2] = { name = "meta.toc-list.line-number.diff" },
        [3] = { name = "punctuation.definition.range.diff" },
      },
    },
    {
      name = "meta.diff.range.context",
      match = [[^(((\-{3}) .+ (\-{4}))|((\*{3}) .+ (\*{4})))$\n?]],
      captures = {
        [3] = { name = "punctuation.definition.range.diff" },
        [4] = { name = "punctuation.definition.range.diff" },
        [6] = { name = "punctuation.definition.range.diff" },
        [7] = { name = "punctuation.definition.range.diff" },
      },
    },
    {
      name = "meta.diff.header.from-file",
      match = [[(^(((-{3}) .+)|((\*{3}) .+))$\n?|^(={4}) .+(?= - ))]],
      captures = {
        [4] = { name = "punctuation.definition.from-file.diff" },
        [6] = { name = "punctuation.definition.from-file.diff" },
        [7] = { name = "punctuation.definition.from-file.diff" },
      },
    },
    {
      name = "meta.diff.header.to-file",
      match = [[(^(\+{3}) .+$\n?| (-) .* (={4})$\n?)]],
      captures = {
        [2] = { name = "punctuation.definition.to-file.diff" },
        [3] = { name = "punctuation.definition.to-file.diff" },
        [4] = { name = "punctuation.definition.to-file.diff" },
      },
    },
    {
      match = [[^(((>)( .*)?)|((\+).*))$\n?]],
      name = "markup.inserted.diff",
      captures = {
        [3] = { name = "punctuation.definition.inserted.diff" },
        [6] = { name = "punctuation.definition.inserted.diff" },
      },
    },
    {
      name = "markup.changed.diff",
      match = [[^(!).*$\n?]],
      captures = {
        [1] = { name = "punctuation.definition.inserted.diff" },
      },
    },
    {
      name = "markup.deleted.diff",
      match = [[^(((<)( .*)?)|((-).*))$\n?]],
      captures = {
        [3] = { name = "punctuation.definition.inserted.diff" },
        [6] = { name = "punctuation.definition.inserted.diff" },
      },
    },
    {
      name = "meta.diff.header.index",
      match = [[^Index(:) (.+)$\n?]],
      captures = {
        [1] = { name = "punctuation.separator.key-value.diff" },
        [2] = { name = "meta.toc-list.file-name.diff" },
      },
    },
    {
      name = "meta.diff.header.index",
      match = [[^index (\h{7})..(\h{7}) ([0-7]{3,})$\n?]],
      captures = {
        [1] = { name = "punctuation.definition.from-file.sha1.diff" },
        [2] = { name = "punctuation.definition.to-file.sha1.diff" },
        [3] = { name = "meta.diff.header.mode" },
      },
    },
    {
      name = "meta.diff.header.command",
      match = [[^diff (-.+ )*(.+) (.+)$\n?]],
      captures = {
        [1] = { name = "meta.diff.header.command.flags" },
        [2] = { name = "punctuation.definition.from-file.command.diff" },
        [3] = { name = "punctuation.definition.to-file.command.diff" },
      },
    },
  },
  scopeName = "source.diff",
}
