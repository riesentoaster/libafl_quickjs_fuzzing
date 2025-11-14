//==-- handle_cxx.cpp - Helper function for Clang fuzzers ------------------==//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Implements HandleCXX for use by the Clang fuzzers.
//
//===----------------------------------------------------------------------===//

#include "handle_cxx.h"

#include "clang/CodeGen/CodeGenAction.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Lex/PreprocessorOptions.h"
#include "clang/Tooling/Tooling.h"
#include "llvm/Option/Option.h"
#include "clang/Basic/DiagnosticIDs.h"
#include "clang/Basic/DiagnosticCategories.h"

using namespace clang;

// Global variable for tracking compilation step (C linkage to avoid name mangling)
extern "C" size_t __afl_correctness_step;

namespace {
class StepTrackingDiagConsumer : public DiagnosticConsumer {
  size_t ErrorStep = 0;

  size_t getStepFromCategory(unsigned DiagID) {
    unsigned CatID = DiagnosticIDs::getCategoryNumberForDiag(DiagID);
    
    // Map category enum to unique step number (starting from 1)
    switch (CatID) {
      case diag::DiagCat_None:
        return 1;
      case diag::DiagCat_Lexical_or_Preprocessor_Issue:
        return 2;
      case diag::DiagCat_Parse_Issue:
        return 3;
      case diag::DiagCat_AST_Deserialization_Issue:
        return 4;
      case diag::DiagCat_Modules_Issue:
        return 5;
      case diag::DiagCat_Semantic_Issue:
        return 6;
      case diag::DiagCat_Lambda_Issue:
        return 7;
      case diag::DiagCat_Coroutines_Issue:
        return 8;
      case diag::DiagCat_Concepts_Issue:
        return 9;
      case diag::DiagCat_Generics_Issue:
        return 10;
      case diag::DiagCat_ARC_Semantic_Issue:
        return 11;
      case diag::DiagCat_ARC_Weak_References:
        return 12;
      case diag::DiagCat_ARC_Restrictions:
        return 13;
      case diag::DiagCat_ARC_Retain_Cycle:
        return 14;
      case diag::DiagCat_ARC_and__properties:
        return 15;
      case diag::DiagCat_ARC_Casting_Rules:
        return 16;
      case diag::DiagCat_ARC_Parse_Issue:
        return 17;
      case diag::DiagCat_Inline_Assembly_Issue:
        return 18;
      case diag::DiagCat_Backend_Issue:
        return 19;
      case diag::DiagCat_AST_Serialization_Issue:
        return 20;
      default:
        return 22; // Unknown category
    }
  }

public:
  void HandleDiagnostic(DiagnosticsEngine::Level DiagLevel,
                        const Diagnostic &Info) override {
    if (DiagLevel >= DiagnosticsEngine::Error && ErrorStep == 0) {
      ErrorStep = getStepFromCategory(Info.getID());
    }
    DiagnosticConsumer::HandleDiagnostic(DiagLevel, Info);
  }

  size_t getStep() const { 
    // Return error step if error occurred, otherwise return success step (highest number)
    return ErrorStep != 0 ? ErrorStep : 23;
  }
};
} // anonymous namespace

void clang_fuzzer::HandleCXX(const std::string &S,
                             const char *FileName,
                             const std::vector<const char *> &ExtraArgs) {
  llvm::opt::ArgStringList CC1Args;
  CC1Args.push_back("-cc1");
  for (auto &A : ExtraArgs)
    CC1Args.push_back(A);
  CC1Args.push_back(FileName);

  llvm::IntrusiveRefCntPtr<FileManager> Files(
      new FileManager(FileSystemOptions()));
  StepTrackingDiagConsumer Diags;
  DiagnosticOptions DiagOpts;
  DiagnosticsEngine Diagnostics(DiagnosticIDs::create(), DiagOpts, &Diags,
                                false);
  std::unique_ptr<clang::CompilerInvocation> Invocation(
      tooling::newInvocation(&Diagnostics, CC1Args, /*BinaryName=*/nullptr));
  std::unique_ptr<llvm::MemoryBuffer> Input =
      llvm::MemoryBuffer::getMemBuffer(S);
  Invocation->getPreprocessorOpts().addRemappedFile(FileName,
                                                    Input.release());
  std::unique_ptr<tooling::ToolAction> action(
      tooling::newFrontendActionFactory<clang::EmitObjAction>());
  std::shared_ptr<PCHContainerOperations> PCHContainerOps =
      std::make_shared<PCHContainerOperations>();
  action->runInvocation(std::move(Invocation), Files.get(), PCHContainerOps,
                        &Diags);
  
  // Get the step: error step (1-20 for known categories, 22 for unknown) if error occurred, or 23 if compilation succeeded
  __afl_correctness_step = Diags.getStep();
}
