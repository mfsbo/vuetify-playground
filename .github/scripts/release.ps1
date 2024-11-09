param(
    [string]$sourceBranch = "main",
    [string]$targetBranch,
    [string]$repository = (Get-Location) # Set default value to current directory
)

# Function to extract PR numbers from commit messages
function Get-PRNumbersFromCommits {
    param (
        [string]$sourceBranch,
        [string]$targetBranch,
        [switch]$Verbose
    )

    # Find the common ancestor (the point of divergence) of the two branches
    $commonAncestor = git merge-base $sourceBranch $targetBranch

    if ($Verbose) {
        Write-Host "Common ancestor: $commonAncestor"
    }

    # Prepare the argument list for the git command
    $gitArguments = @('log', '--oneline', "$commonAncestor..$sourceBranch")

    # Execute the git command and capture the output
    $logOutput = Start-Process git -ArgumentList $gitArguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput 'gitOutput.txt'
    $mergeCommits = Get-Content 'gitOutput.txt' -Raw
    Remove-Item 'gitOutput.txt' -ErrorAction SilentlyContinue

    if ($Verbose) {
        Write-Host "Log output:`n$mergeCommits"
    }

    # Split the output into individual lines (commits)
    $commitArray = $mergeCommits -split '\r?\n'

    if ($Verbose) {
        Write-Host "Number of merge commits: $($commitArray.Length)"
        Write-Host "Merge Commits:"
        $commitArray | ForEach-Object { Write-Host $_ }
    }

    # List to store PR numbers
    $prNumbers = @()

    foreach ($commit in $commitArray) {
        if ($Verbose) {
            Write-Host "Processing commit: $commit"
        }

        # If the commit message matches the merge PR pattern, extract the PR number
        if ($commit -match "Merge pull request #(?<number>\d+)") {
            $prNumbers += $matches.number
            if ($Verbose) {
                Write-Host "Match found: $($matches.number)"
            }
        }
    }

    if ($Verbose) {
        Write-Host "PR numbers extracted: $prNumbers"
    }

    return $prNumbers
    
}


# Step 0: Preparation
# Navigate to the repository directory; this is crucial before any git operations
if ($repository) {
    Set-Location -Path $repository
}

# Fetch the latest changes from the remote repository
git fetch origin

# Checkout both branches to ensure they exist locally
git checkout $sourceBranch
git pull && git push
git checkout $targetBranch
git pull && git push

# Switch back to the original branch or the source branch (based on your preference)
git checkout $sourceBranch

# Section 1: Create Title
$packageJsonPath = Join-Path $repository "package.json" # path to package.json
if (-Not (Test-Path -Path $packageJsonPath -PathType Leaf)) {
    throw "Cannot find package.json in the repository path: $repository"
}
$packageJsonContent = Get-Content $packageJsonPath | Out-String | ConvertFrom-Json
$version = $packageJsonContent.version
$title = "$targetBranch Release $version"

# Section 2: Create Description
$description = ""
$prNumbers = Get-PRNumbersFromCommits -sourceBranch $sourceBranch -targetBranch $targetBranch

foreach ($number in $prNumbers) {
    $description += "`n- #$number"
}

# If no PR numbers were found, use the title as the description
if ([string]::IsNullOrWhiteSpace($description)) {
    $description = $title
}

# Section 3: Create PR
$prOutput = gh pr create -B $targetBranch -H $sourceBranch -t $title -b $description 2>&1
Write-Host "PR creation output: $prOutput"  # Log the output for debugging


if ($LASTEXITCODE -eq 0) {
    # Attempt to extract URL
    $prLink = [regex]::Match($prOutput, 'https?://\S+').Value

    if ([string]::IsNullOrWhiteSpace($prLink) -or $prLink -eq 'True') {
        Write-Host "PR seems to be created, but failed to extract URL from the output. Check the repository on GitHub for the new PR."
    } else {
        Write-Host "Pull Request created successfully: $prLink"
        Start-Process $prLink
    }
} else {
    Write-Error "Failed to create pull request: $prOutput"
}