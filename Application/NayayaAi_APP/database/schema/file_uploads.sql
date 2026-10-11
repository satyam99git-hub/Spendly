-- =============================================================================
--  file_uploads
-- =============================================================================
--  Metadata for every uploaded artefact (avatars, documents). The bytes live on
--  disk or S3; this table is the index over them.
--
--  `storage_backend` + `storage_key` keep the record backend-agnostic, so moving
--  from local disk to S3 later is a StorageService change plus a backfill, not a
--  schema migration.
--
--  `original_filename` is what the user called it; `stored_filename` is the
--  sanitised, collision-proof name on disk. Never serve a file using the original
--  name -- that is a path-traversal and content-sniffing vector.
--
--  `checksum_sha256` deduplicates re-uploads and detects corruption.
--
--  Soft delete: `deleted_at` is set immediately so the API stops serving the file,
--  while the physical bytes are removed asynchronously by a sweeper. Deleting the
--  row and the object in one request means a failed unlink orphans the record.
-- =============================================================================

CREATE TABLE IF NOT EXISTS file_uploads (
    id                  BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,
    public_id           CHAR(36)            NOT NULL COMMENT 'UUIDv4 used in file URLs',

    user_id             BIGINT UNSIGNED         NULL
                        COMMENT 'Uploader; NULL once the account is hard-deleted',

    original_filename   VARCHAR(255)        NOT NULL,
    stored_filename     VARCHAR(255)        NOT NULL COMMENT 'Sanitised name on the backend',
    storage_backend     ENUM('local', 's3')  NOT NULL DEFAULT 'local',
    storage_key         VARCHAR(512)        NOT NULL COMMENT 'Path or object key',

    mime_type           VARCHAR(100)        NOT NULL,
    file_size           BIGINT UNSIGNED     NOT NULL COMMENT 'Bytes',
    checksum_sha256     CHAR(64)                NULL,

    category            ENUM('avatar', 'document', 'attachment', 'other')
                        NOT NULL DEFAULT 'other',
    is_public           BOOLEAN             NOT NULL DEFAULT FALSE
                        COMMENT 'FALSE = requires an authorised, signed URL',

    created_at          DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP,
    deleted_at          DATETIME                NULL
                        COMMENT 'Soft delete; sweeper removes the object afterwards',

    PRIMARY KEY (id),
    UNIQUE KEY uq_file_uploads_public_id (public_id),

    KEY idx_file_uploads_user (user_id, category, deleted_at),
    KEY idx_file_uploads_checksum (checksum_sha256),
    KEY idx_file_uploads_deleted (deleted_at),

    CONSTRAINT fk_file_uploads_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE SET NULL ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Uploaded file metadata';
