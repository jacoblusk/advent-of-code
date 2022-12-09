#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct file {
    char* name;
    size_t size;
};


#define CONDITIONAL_SIZE 100000
#define CHILDREN_ALLOC_SIZE 10
#define FILE_ALLOC_SIZE 10
#define ALLOC_STRING_SIZE 10

#define TOTAL_SPACE 70000000
#define NEEDED_TOTAL 30000000

struct directory;
struct directory {
    char* name;
    struct directory* parent;
    struct directory** children;
    size_t children_size;
    size_t children_capacity;

    struct file** files;
    size_t files_size;
    size_t files_capacity;
};

[[nodiscard]] struct directory* make_directory(char* name, struct directory* parent)
{
    struct directory* directory = malloc(sizeof(struct directory));

    directory->name = name;
    directory->parent = parent;
    directory->children = malloc(sizeof(struct directory*) * CHILDREN_ALLOC_SIZE);
    directory->children_capacity = CHILDREN_ALLOC_SIZE;
    directory->children_size = 0;

    directory->files = malloc(sizeof(struct file*) * FILE_ALLOC_SIZE);
    directory->files_capacity = FILE_ALLOC_SIZE;
    directory->files_size = 0;

    return directory;
}

void directory_add_file(struct directory* directory, struct file* file)
{
    if (directory->files_capacity <= directory->files_size - 1) {
        directory->files_capacity += FILE_ALLOC_SIZE;
        directory->files = realloc(directory->files, sizeof(struct file*) * directory->files_capacity);
    }

    directory->files[directory->files_size++] = file;
}

void directory_add_child(struct directory* directory, struct directory* child)
{
    if (directory->children_capacity <= directory->children_size - 1) {
        directory->children_capacity += CHILDREN_ALLOC_SIZE;
        directory->children = realloc(directory->children, sizeof(struct directory*) * directory->children_capacity);
    }

    directory->children[directory->children_size++] = child;
}

[[nodiscard]] struct file* make_file(char* name, size_t size)
{
    struct file* file = malloc(sizeof(struct file));

    file->name = name;
    file->size = size;

    return file;
}

struct directory* process_line(char* line, struct directory *parent)
{
    char* token;
    const char* delims = " ";
    token = strtok(line, delims);

    if(strlen(line) == 0) {
        return parent;
    }

    if (token[0] == '$') {
        char *command = strtok(NULL, delims);
        if(strcmp(command, "ls") == 0) {
          printf("processing ls\n");
        } else if(strcmp(command, "cd") == 0) {
          printf("processing cd\n");
          char *dirname = strtok(NULL, delims);
          if(strcmp(dirname, "..") == 0) {
            return parent->parent;
          }

          for(size_t i = 0; i < parent->children_size; i++) {
            if(strcmp(dirname, parent->children[i]->name) == 0) {
              return parent->children[i];
            }
          }
        }
    } else if (strcmp(token, "dir") == 0) {
        char *dirname = strtok(NULL, delims);
        printf("processing dir %s\n", dirname);
        struct directory *directory = make_directory(dirname, parent);
        directory_add_child(parent, directory);
    } else {
        // parse file
        int filesize = atoi(token);
        char* filename = strtok(NULL, delims);
        printf("processing file %s:%d\n", filename, filesize);
        struct file *file = make_file(filename, filesize);
        directory_add_file(parent, file);
    }

    return parent;
}

_Bool getline(FILE* input, char** line_out)
{
    char c;
    char* line = malloc(sizeof(char) * ALLOC_STRING_SIZE);
    size_t i = 0;
    size_t capacity = ALLOC_STRING_SIZE;

    for (i = 0; (c = fgetc(input)) != EOF && c != '\n'; i++) {
        if (i >= (capacity - 1)) {
            capacity += ALLOC_STRING_SIZE;
            line = realloc(line, sizeof(char) * capacity);
        }

        line[i] = c;
    }

    line[i] = '\0';
    *line_out = line;

    return c == EOF ? 0 : 1;
}

size_t get_directory_size(struct directory *directory) {
    size_t file_sizes = 0;
    for(size_t i = 0; i < directory->files_size; i++) {
        file_sizes += directory->files[i]->size;
    }

    size_t directory_sizes = 0;
    for(size_t i = 0; i < directory->children_size; i++) {
        directory_sizes += get_directory_size(directory->children[i]);
    }

    return file_sizes + directory_sizes;
}

size_t total_conditional_sum_of_directories(struct directory *parent) {
    size_t total_conditional_sum = 0;
    size_t parent_size = get_directory_size(parent);

    if(parent_size < CONDITIONAL_SIZE) {
        total_conditional_sum += parent_size;
    }

    for(int i = 0; i < parent->children_size; i++) {
        total_conditional_sum += total_conditional_sum_of_directories(parent->children[i]);
    }

    return total_conditional_sum;
}

#define MIN(x, y) (((x) < (y)) ? (x) : (y))

size_t find_smallest_directory_to_delete(struct directory *parent, size_t required_size) {
    size_t minimum_size = (size_t)-1;

    for(int i = 0; i < parent->children_size; i++) {
        size_t children_size = get_directory_size(parent->children[i]);

        if(children_size > required_size) {
            minimum_size = MIN(children_size, minimum_size);
            size_t minimum_child_size = find_smallest_directory_to_delete(parent->children[i], required_size);
            minimum_size = MIN(minimum_child_size, minimum_size);
        }
    }

    return minimum_size;
}

int main([[maybe_unused]] int argc, [[maybe_unused]] char** argv)
{
    FILE* input;
    char* line;
    _Bool result;
    struct directory *root;
    struct directory *active_directory;

    root = make_directory("/", NULL);
    active_directory = root;

    result = fopen_s(&input, "day7.txt", "r");
    if (result) {
        return EXIT_FAILURE;
    }

    do {
        result = getline(input, &line);
        printf("%s\n", line);

        active_directory = process_line(line, active_directory);
    } while (result);

    size_t total_sum = total_conditional_sum_of_directories(root);
    printf("total_sum: %zu\n", total_sum);

    size_t root_size = get_directory_size(root);

    size_t required_size = NEEDED_TOTAL - (TOTAL_SPACE - root_size);
    printf("required_size: %zu\n", required_size);

    size_t minimum_size = find_smallest_directory_to_delete(root, required_size);
    printf("minimum_size: %zu\n", minimum_size);

    return EXIT_SUCCESS;
}