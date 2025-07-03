# Ubuntu Server Backup Script (Docker + MicroK8s)
This is a single bash script to **back up and restore**:
- Docker containers, images, and volumes- MicroK8s cluster resources, manifests, and persistent config
Use when anticipating many changes to the configuration, setup, or files of Docker or MicroK8s.
---
## Files
| File                          | Purpose                                   ||-------------------------------|-------------------------------------------|| `backup_microk8s_docker.sh`  | Backup/restore script                     || `server-backups/`            | Stores all backup archives (auto-created) |
---
## Requirements
- Ubuntu Server- `bash`, `tar`, `gzip`- Docker installed and running- MicroK8s installed and running
---
## Backup Usage
Run the script to back up everything:
```bash
chmod +x backup_microk8s_docker.sh
./backup_microk8s_docker.sh
```

This will:

- Export all Docker images (`docker save`)
- Archive Docker volumes
- Dump all MicroK8s resources to YAML
- Copy MicroK8s config and manifests
- Save it all to:  
  `~/server-backups/backup-YYYYMMDD-HHMMSS.tar.gz`

---

## Restore Usage

To restore from a backup archive:

```bash
./backup_microk8s_docker.sh --restore /path/to/backup-*.tar.gz
```

This will:

- Re-import Docker images
- Restore Docker volumes
- Stop MicroK8s and restore `/var/snap/microk8s/`
- Restart MicroK8s
- Re-apply all previously deployed Kubernetes resources

---

## Example

```bash
./backup_microk8s_docker.sh
# → creates ~/server-backups/backup-20250702-1830.tar.gz

./backup_microk8s_docker.sh --restore ~/server-backups/backup-20250702-1830.tar.gz
```

---

## Notes

- Ensure you have enough disk space (~equal to your volumes + image size).
- Stop critical services before restoring if needed.
- You can automate the backup via cron for daily/weekly backups.

---

## TODO (Optional Enhancements)

- [ ] Add remote sync to NAS / S3 via `rclone`
- [ ] Add `--dry-run` mode
- [ ] Add email notification on success/failure
- [ ] Add log file support

---

## 🔒 License

MIT – feel free to modify or adapt for personal or commercial use.
