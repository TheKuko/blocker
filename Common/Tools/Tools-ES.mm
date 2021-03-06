//
//  Tools-ES.mm
//  
//
//  Created by Jozef on 18/05/2020.
//
// TODO: NOT ALL ES TYPES ARE SUPPORTED YET !!!
// TODO: CHECK POINTERS FOR NULL!!! (i.e. exec) (and make unit tests for it)
// Inspired by: https://gist.github.com/Omar-Ikram/8e6721d8e83a3da69b31d4c2612a68ba/

#include <any>
#include <bsm/libbsm.h>
#include <EndpointSecurity/EndpointSecurity.h>
#include <iostream>
#include <mach/mach_time.h>
#include <sys/unistd.h>
#include <vector>

#include "Tools.hpp"
#include "Tools-ES.hpp"
#include "../logger.hpp"

const inline std::map<es_event_type_t, const std::string> g_eventTypeToStrMap = {
    // Process
    {ES_EVENT_TYPE_AUTH_EXEC, "ES_EVENT_TYPE_AUTH_EXEC"},
    {ES_EVENT_TYPE_NOTIFY_EXIT, "ES_EVENT_TYPE_NOTIFY_EXIT"},
    {ES_EVENT_TYPE_NOTIFY_FORK, "ES_EVENT_TYPE_NOTIFY_FORK"},
    // File System
    {ES_EVENT_TYPE_NOTIFY_ACCESS, "ES_EVENT_TYPE_NOTIFY_ACCESS"},
    {ES_EVENT_TYPE_AUTH_CHDIR, "ES_EVENT_TYPE_AUTH_CHDIR"},
    {ES_EVENT_TYPE_AUTH_CLONE, "ES_EVENT_TYPE_AUTH_CLONE"},
    {ES_EVENT_TYPE_NOTIFY_CLOSE, "ES_EVENT_TYPE_NOTIFY_CLOSE"},
    {ES_EVENT_TYPE_AUTH_CREATE, "ES_EVENT_TYPE_AUTH_CREATE"},
    {ES_EVENT_TYPE_AUTH_FILE_PROVIDER_MATERIALIZE, "ES_EVENT_TYPE_AUTH_FILE_PROVIDER_MATERIALIZE"},
    {ES_EVENT_TYPE_AUTH_FILE_PROVIDER_UPDATE, "ES_EVENT_TYPE_AUTH_FILE_PROVIDER_UPDATE"},
    {ES_EVENT_TYPE_NOTIFY_EXCHANGEDATA, "ES_EVENT_TYPE_NOTIFY_EXCHANGEDATA"},
    {ES_EVENT_TYPE_AUTH_LINK, "ES_EVENT_TYPE_AUTH_LINK"},
    {ES_EVENT_TYPE_AUTH_MOUNT, "ES_EVENT_TYPE_AUTH_MOUNT"},
    {ES_EVENT_TYPE_AUTH_OPEN, "ES_EVENT_TYPE_AUTH_OPEN"},
    {ES_EVENT_TYPE_AUTH_READDIR, "ES_EVENT_TYPE_AUTH_READDIR"},
    {ES_EVENT_TYPE_AUTH_READLINK, "ES_EVENT_TYPE_AUTH_READLINK"},
    {ES_EVENT_TYPE_AUTH_RENAME, "ES_EVENT_TYPE_AUTH_RENAME"},
    {ES_EVENT_TYPE_AUTH_TRUNCATE, "ES_EVENT_TYPE_AUTH_TRUNCATE"},
    {ES_EVENT_TYPE_AUTH_UNLINK, "ES_EVENT_TYPE_AUTH_UNLINK"},
    {ES_EVENT_TYPE_NOTIFY_UNMOUNT, "ES_EVENT_TYPE_NOTIFY_UNMOUNT"},
    {ES_EVENT_TYPE_NOTIFY_WRITE, "ES_EVENT_TYPE_NOTIFY_WRITE"},
    // System
    {ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN, "ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN"},
    {ES_EVENT_TYPE_NOTIFY_KEXTLOAD, "ES_EVENT_TYPE_NOTIFY_KEXTLOAD"},
    {ES_EVENT_TYPE_NOTIFY_KEXTUNLOAD, "ES_EVENT_TYPE_NOTIFY_KEXTUNLOAD"},
    // !!!: Default --> throws an exception
};

const inline std::map<es_respond_result_t, const std::string> g_respondResultToStrMap = {
    {ES_RESPOND_RESULT_SUCCESS, "ES_RESPOND_RESULT_SUCCESS"},
    ///One or more invalid arguments were provided
    {ES_RESPOND_RESULT_ERR_INVALID_ARGUMENT, "ES_RESPOND_RESULT_ERR_INVALID_ARGUMENT"},
    ///Communication with the ES subsystem failed
    {ES_RESPOND_RESULT_ERR_INTERNAL, "ES_RESPOND_RESULT_ERR_INTERNAL"},
    ///The message being responded to could not be found
    {ES_RESPOND_RESULT_NOT_FOUND, "ES_RESPOND_RESULT_NOT_FOUND"},
    ///The provided message has been responded to more than once
    {ES_RESPOND_RESULT_ERR_DUPLICATE_RESPONSE, "ES_RESPOND_RESULT_ERR_DUPLICATE_RESPONSE"},
    ///Either an inappropriate response API was used for the event type (ensure using proper
    ///es_respond_auth_result or es_respond_flags_result function) or the event is notification only.
    {ES_RESPOND_RESULT_ERR_EVENT_TYPE, "ES_RESPOND_RESULT_ERR_EVENT_TYPE"},
};

const inline static std::map<es_destination_type_t, const std::string> g_destinationTypeToStrMap = {
    {ES_DESTINATION_TYPE_EXISTING_FILE, "ES_DESTINATION_TYPE_EXISTING_FILE"},
    {ES_DESTINATION_TYPE_NEW_PATH, "ES_DESTINATION_TYPE_NEW_PATH"},
};


// MARK: - Custom Casts
@implementation NSString (alternativeConstructorsEs)

+(NSString*)stringFromEsString:(es_string_token_t const &)esString
{
    NSString *res = @"";

    if (esString.data && esString.length > 0) {
        // es_string_token.data is a pointer to a null-terminated string
        res = [NSString stringWithUTF8String:esString.data];
    }

    return res;
}

@end

std::string to_string(const es_string_token_t &esString)
{
    if (esString.data == nullptr || esString.length <= 0)
        return "(null)";
    
    return std::string(esString.data, esString.length);
}

std::vector<std::string> paths_from_event(const es_message_t * const msg)
{
#pragma message("Does not support all events!")

    std::vector<std::string> eventPaths;
    if (msg == nullptr)
        return eventPaths;

    switch(msg->event_type) {
        // File System
        case ES_EVENT_TYPE_NOTIFY_ACCESS:
            eventPaths.push_back(to_string(msg->event.access.target->path));
            break;
        case ES_EVENT_TYPE_AUTH_CHDIR:
            eventPaths.push_back(to_string(msg->event.chdir.target->path));
            break;
        case ES_EVENT_TYPE_AUTH_CREATE:
        {
            std::string path;
            if (msg->event.create.destination_type == ES_DESTINATION_TYPE_EXISTING_FILE)
                path = to_string(msg->event.create.destination.existing_file->path);
            else {
                path = to_string(msg->event.create.destination.new_path.dir->path)
                        + "/"
                        + to_string(msg->event.create.destination.new_path.filename);

            }
            eventPaths.push_back(path);
            break;
        }
        case ES_EVENT_TYPE_AUTH_CLONE:
            eventPaths.push_back(to_string(msg->event.clone.source->path));
            eventPaths.push_back(to_string(msg->event.clone.target_dir->path)
                                 + "/"
                                 + to_string(msg->event.clone.target_name));
            break;
        case ES_EVENT_TYPE_NOTIFY_CLOSE:
            eventPaths.push_back(to_string(msg->event.close.target->path));
            break;
        case ES_EVENT_TYPE_AUTH_FILE_PROVIDER_MATERIALIZE:
            eventPaths.push_back(to_string(msg->event.file_provider_materialize.source->path));
            eventPaths.push_back(to_string(msg->event.file_provider_materialize.target->path));
            break;
        case ES_EVENT_TYPE_AUTH_FILE_PROVIDER_UPDATE:
            eventPaths.push_back(to_string(msg->event.file_provider_update.source->path));
            eventPaths.push_back(to_string(msg->event.file_provider_update.target_path));
            break;
        case ES_EVENT_TYPE_NOTIFY_EXCHANGEDATA:
            eventPaths.push_back(to_string(msg->event.exchangedata.file1->path));
            eventPaths.push_back(to_string(msg->event.exchangedata.file2->path));
            break;
        case ES_EVENT_TYPE_AUTH_LINK:
            eventPaths.push_back(to_string(msg->event.link.source->path));
            eventPaths.push_back(to_string(msg->event.link.target_dir->path)
                                 + "/"
                                 + to_string(msg->event.link.target_filename));
            break;
        case ES_EVENT_TYPE_AUTH_OPEN:
            eventPaths.push_back(to_string(msg->event.open.file->path));
            break;
        case ES_EVENT_TYPE_AUTH_READDIR:
            eventPaths.push_back(to_string(msg->event.readdir.target->path));
            break;
        case ES_EVENT_TYPE_AUTH_READLINK:
            eventPaths.push_back(to_string(msg->event.readlink.source->path));
            break;
        case ES_EVENT_TYPE_AUTH_RENAME:
        {
            eventPaths.push_back(to_string(msg->event.rename.source->path));

            std::string path;
            if (msg->event.rename.destination_type == ES_DESTINATION_TYPE_EXISTING_FILE)
                path = to_string(msg->event.rename.destination.existing_file->path);
            else {
                path = to_string(msg->event.rename.destination.new_path.dir->path)
                        + "/"
                        + to_string(msg->event.rename.destination.new_path.filename);

            }
            eventPaths.push_back(path);
            break;
        }
        case ES_EVENT_TYPE_AUTH_TRUNCATE:
            eventPaths.push_back(to_string(msg->event.truncate.target->path));
            break;
        case ES_EVENT_TYPE_AUTH_UNLINK:
            eventPaths.push_back(to_string(msg->event.unlink.parent_dir->path));
            eventPaths.push_back(to_string(msg->event.unlink.target->path));
            break;
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            eventPaths.push_back(to_string(msg->event.write.target->path));
            break;
        default:
            break;
    }
    return eventPaths;
}

std::any getDefaultESResponse(const es_message_t * const msg)
{
    if (msg == nullptr)
        return std::nullopt;

    std::any ret;
    if (msg->event_type == ES_EVENT_TYPE_AUTH_OPEN)
       ret = static_cast<uint32_t>(msg->event.open.fflag);
    else
       ret = static_cast<es_auth_result_t>(ES_AUTH_RESULT_ALLOW);

    return ret;
}

// MARK: - Endpoint Security Logging
// MARK: Process Events
std::ostream & operator << (std::ostream &out, const es_event_exec_t &event)
{
    out << "event.exec.target:\n" << event.target;

    // Log program arguments
    const uint32_t argc = es_exec_arg_count(&event);
    out << std::endl << "event.exec.arg_count: " << argc;

    // Extract each argument and log it out
    for (uint32_t i = 0; i < argc; i++)
        out << std::endl << "arg " << i << ": " << es_exec_arg(&event, i);

    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_exit_t &event)
{
    out << "event.exit.stat: " << event.stat;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_fork_t &event)
{
    out << "event.fork.child:\n" << event.child;
    return out;
}

// MARK: File System Events
std::ostream & operator << (std::ostream &out, const es_event_access_t &event)
{
    out << "event.access.mode: 0x" << std::hex << event.mode << std::dec << "(" << faflagstostr(event.mode) << ")";
    out << std::endl << "event.access.target:\n" << event.target;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_clone_t &event)
{
    out << "event.clone.source:\n" << event.source;
    out << std::endl << "event.clone.target_dir:\n" << event.target_dir;
    out << std::endl << "event.clone.target_name: " << event.target_name;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_chdir_t &chdir)
{
    out << "event.chdir.target:\n" << chdir.target;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_close_t &event)
{
    out << "event.close.modified: " << event.modified;
    out << std::endl << "event.close.target: \n" << event.target;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_create_t &event)
{
    out << "event.create.destination_type: " << g_destinationTypeToStrMap.at(event.destination_type);
    if (event.destination_type == ES_DESTINATION_TYPE_EXISTING_FILE) {
        out << std::endl << "event.create.destination.existing_file:\n" << event.destination.existing_file;
    } else {
        out << std::endl << "event.create.destination.new_path.dir:\n" << event.destination.new_path.dir;
        out << std::endl << "event.create.destination.new_path.filename: " << event.destination.new_path.filename;
    }
    return out;
    // TODO: acl
}

std::ostream & operator << (std::ostream &out, const es_event_file_provider_materialize_t &event)
{
    out << "event.file_provider_materialize.instigator:\n" << event.instigator;
    out << std::endl << "event.file_provider_materialize.source:\n" << event.source;
    out << std::endl << "event.file_provider_materialize.target:\n" << event.target;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_file_provider_update_t &event)
{
    out << std::endl << "event.file_provider_update.source:\n" << event.source;
    out << std::endl << "event.file_provider_update.target_path: " << event.target_path;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_exchangedata_t &event)
{
    out << "event.exchangedata.file1:\n" << event.file1;
    out << std::endl << "event.exchangedata.file2:\n" << event.file2;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_link_t &event)
{
    out << "event.link.source:\n" << event.source;
    out << std::endl << "event.link.target_dir:\n" << event.target_dir;
    out << std::endl << "event.link.target_filename: " << event.target_filename;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_mount_t &event)
{
    out << "event.mount.statfs:\n" << event.statfs;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_open_t &event)
{
    char *flags = esfflagstostr(event.fflag);
    out << "event.open.fflag: " << flags << " (0x" << std::hex << event.fflag << std::dec << ")";
    out << std::endl << event.file;
    
    free(flags);
    flags = nullptr;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_readdir_t &event)
{
    out << "event.readdir.target:\n" << event.target;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_readlink_t &event)
{
    out << "event.readlink.source:\n" << event.source;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_rename_t &event)
{
    out << "event.rename.source:\n" << event.source;
    out << std::endl << "event.rename.destination_type: " << g_destinationTypeToStrMap.at(event.destination_type);
    if (event.destination_type == ES_DESTINATION_TYPE_EXISTING_FILE) {
        out << std::endl << "event.rename.destination.existing_file:\n" << event.destination.existing_file;
    } else {
        out << std::endl << "event.rename.destination.new_path.dir:\n" << event.destination.new_path.dir;
        out << std::endl << "event.rename.destination.new_path.filename: " << event.destination.new_path.filename;
    }
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_truncate_t &event)
{
    out << "event.truncate.target:\n" << event.target;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_unlink_t &event)
{
    out << "event.unlink.target:\n" << event.target;
    out << std::endl << "event.unlink.parent_dir" << event.parent_dir;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_unmount_t &event)
{
    out << "event.unmount.statfs:\n" << event.statfs;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_write_t &event)
{
    out << "event.write.target:\n" << event.target;
    return out;
}

// MARK: System Events
std::ostream & operator << (std::ostream &out, const es_event_iokit_open_t &event)
{
    out << "event.iokit_open.user_client_type: " << event.user_client_type;
    out << std::endl << "event.iokit_open.user_client_class: " << event.user_client_class;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_kextload_t &event)
{
    out << "event.kextload.identifier: " << event.identifier;
    return out;
}

std::ostream & operator << (std::ostream &out, const es_event_kextunload_t &event)
{
    out << "event.kextunload.identifier: " << event.identifier;
    return out;
}

// MARK: ES Types
std::ostream & operator << (std::ostream &out, const es_message_t *msg)
{
    if (msg == nullptr)
        return out;

    out << "--- EVENT MESSAGE ----";
    out << std::endl << "event_type: " << g_eventTypeToStrMap.at(msg->event_type) << " (" << msg->event_type << ")";
     // Note: Message structure could change in future versions
    out << std::endl << "version: " << msg->version;
    out << std::endl << "time: " << (long long) msg->time.tv_sec << "." << msg->time.tv_nsec;
    out << std::endl << "mach_time: " << (long long) msg->mach_time;

    // It's very important that the message is processed within the deadline:
    // https://developer.apple.com/documentation/endpointsecurity/es_message_t/3334985-deadline
    out << std::endl << "deadline: " << (long long) msg->deadline;

    uint64_t deadlineInterval = msg->deadline;
    if(deadlineInterval > 0)
        deadlineInterval -= msg->mach_time;

    out << std::endl << "deadline interval: " << (long long) deadlineInterval << " (" << (int) (deadlineInterval / 1.0e9) << " seconds)";

    out << std::endl << "action_type: " << ((msg->action_type == ES_ACTION_TYPE_AUTH) ? "Auth" : "Notify");
    out << std::endl << "- process -\n" << msg->process;
    out << std::endl << "- event -";
    out << std::endl << "sequence number: " << msg->seq_num << std::endl;

     // Type specific logging
    switch(msg->event_type) {
        // Process
        case ES_EVENT_TYPE_AUTH_EXEC:
            out << msg->event.exec;
            break;
        case ES_EVENT_TYPE_NOTIFY_EXIT:
            out << msg->event.exit;
            break;
        case ES_EVENT_TYPE_NOTIFY_FORK:
            out << msg->event.fork;
            break;
        // File System
        case ES_EVENT_TYPE_NOTIFY_ACCESS:
            out << msg->event.access;
            break;
        case ES_EVENT_TYPE_AUTH_CLONE:
            out << msg->event.clone;
            break;
        case ES_EVENT_TYPE_NOTIFY_CLOSE:
            out << msg->event.close;
            break;
        case ES_EVENT_TYPE_AUTH_CHDIR:
            out << msg->event.chdir;
            break;
        case ES_EVENT_TYPE_AUTH_CREATE:
            out << msg->event.create;
            break;
        case ES_EVENT_TYPE_AUTH_FILE_PROVIDER_MATERIALIZE:
            out << msg->event.file_provider_materialize;
            break;
        case ES_EVENT_TYPE_AUTH_FILE_PROVIDER_UPDATE:
            out << msg->event.file_provider_update;
            break;
        case ES_EVENT_TYPE_NOTIFY_EXCHANGEDATA:
            out << msg->event.exchangedata;
            break;
        case ES_EVENT_TYPE_AUTH_LINK:
            out << msg->event.link;
            break;
        case ES_EVENT_TYPE_AUTH_MOUNT:
            out << msg->event.mount;
            break;
        case ES_EVENT_TYPE_AUTH_OPEN:
            out << msg->event.open;
            break;
        case ES_EVENT_TYPE_AUTH_READDIR:
            out << msg->event.readdir;
            break;
        case ES_EVENT_TYPE_AUTH_READLINK:
            out << msg->event.readlink;
            break;
        case ES_EVENT_TYPE_AUTH_RENAME:
            out << msg->event.rename;
            break;
        case ES_EVENT_TYPE_AUTH_TRUNCATE:
            out << msg->event.truncate;
            break;
        case ES_EVENT_TYPE_AUTH_UNLINK:
            out << msg->event.unlink;
            break;
        case ES_EVENT_TYPE_NOTIFY_UNMOUNT:
            out << msg->event.unmount;
            break;
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            out << msg->event.write;
            break;
        // System
        case ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN:
            out << msg->event.iokit_open;
            break;
        case ES_EVENT_TYPE_NOTIFY_KEXTLOAD:
            out << msg->event.kextload;
            break;
        case ES_EVENT_TYPE_NOTIFY_KEXTUNLOAD:
            out << msg->event.kextunload;
            break;
        case ES_EVENT_TYPE_LAST:
        default:
            out << "Printing not implemented yet: " << g_eventTypeToStrMap.at(msg->event_type);
            break;
    }
    return out;
}

std::ostream & operator << (std::ostream &out, const es_string_token_t &esString)
{
    out << (esString.data != nullptr ? std::string(esString.data, esString.length) : "(null)");
    return out;
}

std::ostream & operator << (std::ostream &out, const es_file_t *file)
{
    if (file == nullptr)
        return out;

    out << "  file.path: " << file->path;
    out << std::endl << "  file.path_truncated: " << file->path_truncated;
    out << std::endl << "  file.stats: " << "TO BE DONE";
    return out;
}

std::ostream & operator << (std::ostream &out, const es_statfs_t *stats)
{
    if (stats == nullptr)
        return out;
    out << "   statfs: " << "TO BE DONE";
    return out;
}

std::ostream & operator << (std::ostream &out, const es_process_t * const proc)
{
    if (proc == nullptr)
        return out;

    out << "  proc.pid: " << audit_token_to_pid(proc->audit_token);
    out << std::endl << "  proc.ppid: " << proc->ppid;
    out << std::endl << "  proc.original_ppid: " << proc->original_ppid;
    out << std::endl << "  proc.ruid: " << audit_token_to_ruid(proc->audit_token);
    out << std::endl << "  proc.euid: " << audit_token_to_euid(proc->audit_token);
    out << std::endl << "  proc.rgid: " << audit_token_to_rgid(proc->audit_token);
    out << std::endl << "  proc.egid: " << audit_token_to_egid(proc->audit_token);
    out << std::endl << "  proc.group_id: " << proc->group_id;
    out << std::endl << "  proc.session_id: " << proc->session_id;

    char *flags = csflagstostr(proc->codesigning_flags);
    out << std::endl << "  proc.codesigning_flags: " << flags << " (0x" << std::hex << proc->codesigning_flags << std::dec << ")";
    free(flags);
    flags = nullptr;

    out << std::endl << "  proc.is_platform_binary: " << proc->is_platform_binary;
    out << std::endl << "  proc.is_es_client: " << proc->is_es_client;
    out << std::endl << "  proc.signing_id: " << proc->signing_id;
    out << std::endl << "  proc.team_id: " << proc->team_id;

    out << std::endl << "  proc.cdhash: 0x" << std::hex;
    for (unsigned int i=0; i != CS_CDHASH_LEN; i++)
        out << (proc->cdhash[i]>>4) << (proc->cdhash[i]&0x0f);
    out << std::dec << std::endl << "  proc.executable.path:\n" << proc->executable;

    return out;
}
