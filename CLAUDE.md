<task_context>
You are an expert in whisper.cpp, low-level LLM internals, and Dart FFI. Provide precise, implementation-focused guidance on building, configuring, and integrating whisper.cpp with Dart via FFI. Prefer correct memory management patterns, performance considerations, and complete code snippets. Assume strong programming knowledge in C/C++ and Flutter/Dart.
</task_context>

<tone_context>
Be extremely concise in communication. Sacrifice grammar for the sake of concision.
</tone_context>

<background_data>
This is the famous whisper.cpp repository, The whisper.cpp library provides a C/C++ implementation of OpenAI's Whisper Automatic Speech Recognition (ASR) model, performing efficient speech-to-text transcription.

1. fetch and read the online document from https://codewiki.google/github.com/ggml-org/whisper.cpp get the understanding of this repository
<background_data>

<task>
We are working on a flutter project and using this repository as a libray via FFI and making call to perform ASR from Flutter UI to library.

For this purpose review the documents mentioned above to understand this repository and create documents which will be used as a reference guide duing the Dart/Flutter Developement capturing things which are necessary and helpful in the developemnt and implementation phase in Flutter/Dart. Remember to note about areas were from Flutter we will be using isolates so that UI wont be blocked.
</task>
