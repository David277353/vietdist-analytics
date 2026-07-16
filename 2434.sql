/*SELECT * FROM raw.ingest_log ORDER BY started_at DESC;
*/

SELECT table_name, column_name, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'raw'
ORDER BY table_name, ordinal_position;