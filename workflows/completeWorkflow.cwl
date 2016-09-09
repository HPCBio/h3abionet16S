#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow

requirements:
 - class: ScatterFeatureRequirement
 - class: InlineJavascriptRequirement
 - class: StepInputExpressionRequirement
 - class: SubworkflowFeatureRequirement
 - $import: readPair.yml

inputs:
  fastqSeqs:
    type:
      type: array
      items: "readPair.yml#FilePair"
  fastqMaxdiffs: int
  fastqMaxEe: float
  minSize: int
  otuRadiusPct: float
  chimeraFastaDb: File
  strandInfo: string

outputs:
  #reports:
  #  type: Directory[]
  #  outputSource: runFastqc/report
 
 # mergedFastQs:
 #    type: File[]
 #    outputSource: merge/mergedFastQ

  filteredFastaFiles:
    type: File[]
    outputSource: filter/filteredFasta

  derepFastaFile:
    type: File
    outputSource: derep/derepFasta

  sortedFastaFile:
    type: File
    outputSource: sort/sortedFasta
  
  otuFastaFile:
    type: File
    outputSource: otuPick/otuFasta

  noChimeraFastaFile:
    type: File
    outputSource: chimeraCheck/chimeraCleanFasta  

steps:
  arrayOfFilePairsToFileArray:
    run:
      class: ExpressionTool
      inputs:
        arrayOfFilePairs:
          type:
            type: array
            items: "readPair.yml#FilePair"
      outputs:
        pairByPairs: File[]
      expression: >
        ${
        var val;
        var ret = [];
        for (val of inputs.arrayOfFilePairs) {
          ret.push(val.forward);
          ret.push(val.reverse);
        }
        return { 'pairByPairs': ret } ; }
    in:
      arrayOfFilePairs: fastqSeqs
    out: [ pairByPairs ]

  runFastqc:
    run: fastqc.cwl
    in:
      fastqFile: arrayOfFilePairsToFileArray/pairByPairs
    scatter: fastqFile
    out: [ report ]

  uparseRename:
    run: uparseRenameWithMetadata.cwl
    in:
      onePair: fastqSeqs
    scatter: onePair
    out: [ renamedPair ]

  merge:
    run: uparseFastqMerge.cwl
    in:
      sampleName:
        source: uparseRename/renamedPair
        valueFrom: $(self.sample_id)
      fastqFileF:
        source: uparseRename/renamedPair
        valueFrom: $(self.forward)
      fastqFileR:
        source: uparseRename/renamedPair
        valueFrom: $(self.reverse)
      fastqMaxdiffs: fastqMaxdiffs
    scatter: [ sampleName, fastqFileF, fastqFileR ]
    scatterMethod: dotproduct
    out: [ mergedFastQ ]

  filter:
    run: uparseFilter.cwl
    in:
      fastqFile: merge/mergedFastQ
      fastqMaxEe: fastqMaxEe
    scatter: [ fastqFile ]
    scatterMethod: dotproduct
    out: [ filteredFasta ]

  # add strip primer step here 
  
  # add truncate length step here

  derep:
    run: uparseDerepWorkAround.cwl
    in:
      fastaFiles: filter/filteredFasta
    out:  [ derepFasta ]

  sort:
    run: uparseSort.cwl
    in: 
      fastaFile: derep/derepFasta
      minSize: minSize
    out: [ sortedFasta ]

  otuPick:
    run: uparseOTUPick.cwl
    in:
      fastaFile: sort/sortedFasta
      otuRadiusPct: otuRadiusPct
    out: [ otuFasta ]

  chimeraCheck:
    run: uparseChimeraCheck.cwl
    in:
      fastaFile: otuPick/otuFasta
      chimeraFastaDb: chimeraFastaDb
      strandInfo: strandInfo
    out: [ chimeraCleanFasta  ] 
