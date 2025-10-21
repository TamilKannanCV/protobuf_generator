import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart';

import '../run_once_process.dart';
import '../utils/file_utils.dart';

class GitHubRepoDownloader {
  static final Directory _githubReposDirectory = Directory(join(FileUtils.temporaryDirectory.path, "github_repos"));
  static final Map<String, RunOnceProcess> _fetchProcesses = {};

  /// Downloads a GitHub repository and returns the path to the cloned directory.
  ///
  /// [repoUrl] should be a GitHub repository URL like:
  /// - https://github.com/owner/repo
  /// - https://github.com/owner/repo.git
  /// - git@github.com:owner/repo.git
  /// - https://custom.github.com/owner/repo (for GitHub Enterprise)
  /// - git@custom.github.com:owner/repo.git (for GitHub Enterprise)
  ///
  /// [branch] specifies which branch/tag to clone (defaults to 'main')
  /// [subPath] specifies a subdirectory within the repo to use as the proto root
  static Future<String> fetchGitHubRepo(String repoUrl, {String branch = 'main', String? subPath}) async {
    final repoKey = '$repoUrl:$branch';

    // Create a unique process for each repo+branch combination
    _fetchProcesses[repoKey] ??= RunOnceProcess();

    await _fetchProcesses[repoKey]!.executeOnce(() async {
      log.info("\nDownloading GitHub repository: $repoUrl (branch: $branch)");

      // Parse repository information
      final repoInfo = _parseGitHubUrl(repoUrl);
      final repoName = '${repoInfo['domain']}_${repoInfo['owner']}_${repoInfo['repo']}_$branch';
      final repoDir = Directory(join(_githubReposDirectory.path, repoName));

      // Clean up existing directory if it exists
      if (await repoDir.exists()) {
        await repoDir.delete(recursive: true);
      }

      await _githubReposDirectory.create(recursive: true);

      // Try git clone first, fall back to ZIP download if git is not available
      try {
        await _cloneWithGit(repoUrl, branch, repoDir);
      } catch (e) {
        log.warning("Git clone failed, trying ZIP download: $e");
        await _downloadAsZip(repoInfo, branch, repoDir);
      }

      return true;
    });

    final repoInfo = _parseGitHubUrl(repoUrl);
    final repoName = '${repoInfo['domain']}_${repoInfo['owner']}_${repoInfo['repo']}_$branch';
    final repoDir = Directory(join(_githubReposDirectory.path, repoName));

    if (subPath != null) {
      return join(repoDir.path, subPath);
    }

    return repoDir.path;
  }

  static Future<void> _cloneWithGit(String repoUrl, String branch, Directory targetDir) async {
    final result = await Process.run(
      'git',
      ['clone', '--depth', '1', '--branch', branch, repoUrl, targetDir.path],
    );

    if (result.exitCode != 0) {
      throw Exception('Git clone failed: ${result.stderr}');
    }
  }

  static Future<void> _downloadAsZip(Map<String, String> repoInfo, String branch, Directory targetDir) async {
    final domain = repoInfo['domain']!;
    final owner = repoInfo['owner']!;
    final repo = repoInfo['repo']!;

    // For custom GitHub domains, we need to use HTTPS with the domain
    final zipUrl = Uri.parse('https://$domain/$owner/$repo/archive/refs/heads/$branch.zip');

    await FileUtils.unzipUri(zipUrl, targetDir.parent);

    // The ZIP extraction creates a directory named like "repo-branch"
    final extractedDir = Directory(join(targetDir.parent.path, '$repo-$branch'));
    if (await extractedDir.exists()) {
      await extractedDir.rename(targetDir.path);
    }
  }

  static Map<String, String> _parseGitHubUrl(String repoUrl) {
    // Handle different GitHub URL formats including custom domains
    RegExpMatch? match;

    // HTTPS format: https://github.com/owner/repo(.git)? or https://custom.github.com/owner/repo(.git)?
    match = RegExp(r'https://([^/]+)/([^/]+)/([^/.]+)(?:\.git)?/?$').firstMatch(repoUrl);
    if (match != null) {
      return {
        'domain': match.group(1)!,
        'owner': match.group(2)!,
        'repo': match.group(3)!,
      };
    }

    // SSH format: git@github.com:owner/repo.git or git@custom.github.com:owner/repo.git
    match = RegExp(r'git@([^:]+):([^/]+)/([^/.]+)(?:\.git)?$').firstMatch(repoUrl);
    if (match != null) {
      return {
        'domain': match.group(1)!,
        'owner': match.group(2)!,
        'repo': match.group(3)!,
      };
    }

    throw ArgumentError('Invalid GitHub URL format: $repoUrl');
  }
}
