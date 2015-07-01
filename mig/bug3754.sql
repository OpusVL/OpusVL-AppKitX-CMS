ALTER TABLE pages
    ADD COLUMN markup_type VARCHAR NOT NULL
    DEFAULT 'standard';
