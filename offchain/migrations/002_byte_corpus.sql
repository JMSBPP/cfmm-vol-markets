-- 002_byte_corpus.sql -- the byte-fidelity fixture.
--
-- Separate from model_run on purpose: adversarial_corpus contains 0x00, 0xFF and 0xC3 0x28, none
-- of which can become a jsonb, so model_run.doc's NOT NULL could not carry them even in a
-- perfectly correct implementation. This table exercises bytea fidelity alone.
--
-- No jsonb column here, and that is the point: the corpus is deliberately neither valid UTF-8 nor
-- valid JSON, and a fixture that could only hold what jsonb accepts would have quietly dropped
-- the one member that corrupts SILENTLY -- the member the whole negative control rests on.
create table byte_corpus (
  name text  not null,
  raw  bytea not null,
  constraint byte_corpus_identity primary key (name)
);
