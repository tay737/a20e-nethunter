#!/usr/bin/env python3
"""Insert KernelSU hooks into an Eureka/ViP3R 4.4.302 tree (R15-Nethunter)."""
import io, os, re, sys

ROOT = sys.argv[1]

EDITS = [
    # (file, anchor_before_decl, extern_decl, anchor_body, call_line)
    ("fs/exec.c",
     "static int do_execveat_common(int fd, struct filename *filename,",
     "extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,\n\t\t\tvoid *envp, int *flags);\n\n",
     "\tchar *pathbuf = NULL;\n",
     "\tksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);\n"),

    ("fs/read_write.c",
     "ssize_t vfs_read(struct file *file, char __user *buf, size_t count, loff_t *pos)",
     "extern int ksu_handle_vfs_read(struct file **file_ptr, char __user **buf_ptr,\n\t\tsize_t *count_ptr, loff_t **pos);\n\n",
     "\tssize_t ret;\n",
     "\tksu_handle_vfs_read(&file, &buf, &count, &pos);\n"),

    ("fs/stat.c",
     "int vfs_fstatat(int dfd, const char __user *filename, struct kstat *stat,",
     "extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n\n",
     "\tint error;\n",
     "\tksu_handle_stat(&dfd, &filename, &flag);\n"),

    ("fs/open.c",
     "SYSCALL_DEFINE3(faccessat, int, dfd, const char __user *, filename, int, mode)",
     "extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,\n\t\t\t\tint *flags);\n\n",
     "\tint res;\n",
     "\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n"),

    ("drivers/input/input.c",
     "static void input_handle_event(struct input_dev *dev,",
     "extern int ksu_handle_input_handle_event(unsigned int *type, unsigned int *code, int *value);\n\n",
     "\tint disposition;\n",
     "\tksu_handle_input_handle_event(&type, &code, &value);\n"),
]


def patch(rel, decl_anchor, decl_text, body_anchor, call_text):
    path = os.path.join(ROOT, rel)
    src = open(path, encoding="utf-8", errors="surrogateescape").read()
    if "ksu_handle" in src:
        print(f"{rel}: already hooked, skipping")
        return
    if decl_anchor not in src:
        print(f"{rel}: DECL ANCHOR MISSING")
        return
    src = src.replace(decl_anchor, decl_text + decl_anchor, 1)
    # find the body anchor after the declaration
    pos = src.index(decl_anchor)
    body_pos = src.find(body_anchor, pos)
    if body_pos < 0:
        print(f"{rel}: BODY ANCHOR MISSING")
        return
    ins = "#ifdef CONFIG_KSU\n" + call_text + "#endif\n"
    src = src[:body_pos] + ins + src[body_pos:]
    open(path, "w", encoding="utf-8", errors="surrogateescape").write(src)
    print(f"{rel}: hooked")


for e in EDITS:
    patch(*e)
