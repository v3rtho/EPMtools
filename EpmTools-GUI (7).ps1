#Requires -Version 5.1
<#
.SYNOPSIS
    WPF GUI Wrapper for the EpmTools PowerShell Module
    (Microsoft Endpoint Privilege Management)
.NOTES
    Requires EPM policy deployed via Microsoft Intune.
    Module: C:\Program Files\Microsoft EPM Agent\EpmTools\EpmCmdlets.dll
    ARM64 devices: automatically relaunched under Windows PowerShell x64.
#>

# -------------------------------------------------------------
# ARM64 / x64 Self-Relaunch Guard
# EpmCmdlets.dll is x64-only. Detect and relaunch if needed.
# -------------------------------------------------------------
$x64Host    = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$is64bit    = [System.Environment]::Is64BitProcess
$isWinPS    = ($PSVersionTable.PSEdition -eq 'Desktop')
$needRelaunch = (-not $isWinPS) -or (-not $is64bit)

if ($needRelaunch) {
    if (Test-Path $x64Host) {
        $me = $MyInvocation.MyCommand.Path
        if (-not [string]::IsNullOrEmpty($me)) {
            Start-Process -FilePath $x64Host `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$me`""
            exit 0
        } else {
            Write-Warning "Cannot auto-relaunch: run this script directly from a .ps1 file."
        }
    } else {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "Windows PowerShell x64 not found at:`n$x64Host`n`nEpmCmdlets.dll requires an x64 process.",
            "Architecture Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        exit 1
    }
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# -------------------------------------------------------------
# XAML
# -------------------------------------------------------------
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="EpmTools — Endpoint Privilege Management"
    Height="900" Width="1100"
    MinHeight="700" MinWidth="850"
    WindowStartupLocation="CenterScreen"
    Background="#0F1117"
    Foreground="#E2E8F0"
    FontFamily="Segoe UI">

    <Window.Resources>
        <!-- Colours -->
        <SolidColorBrush x:Key="PrimaryBg"     Color="#0F1117"/>
        <SolidColorBrush x:Key="SurfaceBg"     Color="#1A1D27"/>
        <SolidColorBrush x:Key="CardBg"        Color="#21253A"/>
        <SolidColorBrush x:Key="AccentBlue"    Color="#3B82F6"/>
        <SolidColorBrush x:Key="AccentGreen"   Color="#22C55E"/>
        <SolidColorBrush x:Key="AccentOrange"  Color="#F59E0B"/>
        <SolidColorBrush x:Key="AccentRed"     Color="#EF4444"/>
        <SolidColorBrush x:Key="BorderColor"   Color="#2D3252"/>
        <SolidColorBrush x:Key="TextPrimary"   Color="#E2E8F0"/>
        <SolidColorBrush x:Key="TextSecondary" Color="#8892AA"/>
        <SolidColorBrush x:Key="TextMuted"     Color="#4B5563"/>

        <!-- Button Style -->
        <Style x:Key="ActionButton" TargetType="Button">
            <Setter Property="Background"   Value="#3B82F6"/>
            <Setter Property="Foreground"   Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"      Value="14,8"/>
            <Setter Property="FontSize"     Value="12"/>
            <Setter Property="FontWeight"   Value="SemiBold"/>
            <Setter Property="Cursor"       Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#2563EB"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#1D4ED8"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Background" Value="#374151"/>
                                <Setter Property="Foreground" Value="#6B7280"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Secondary Button -->
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource ActionButton}">
            <Setter Property="Background" Value="#2D3252"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#374270"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Danger Button -->
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource ActionButton}">
            <Setter Property="Background" Value="#7F1D1D"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#991B1B"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Nav Button -->
        <Style x:Key="NavButton" TargetType="RadioButton">
            <Setter Property="Background"       Value="Transparent"/>
            <Setter Property="Foreground"       Value="#8892AA"/>
            <Setter Property="BorderThickness"  Value="0"/>
            <Setter Property="Padding"          Value="12,10"/>
            <Setter Property="FontSize"         Value="13"/>
            <Setter Property="Cursor"           Value="Hand"/>
            <Setter Property="GroupName"        Value="Nav"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="Border" Background="{TemplateBinding Background}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}"
                                Margin="0,2">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#21253A"/>
                                <Setter Property="Foreground" Value="#E2E8F0"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#1A1D27"/>
                                <Setter Property="Foreground" Value="#CBD5E1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- TextBox Style -->
        <Style x:Key="InputBox" TargetType="TextBox">
            <Setter Property="Background"      Value="#21253A"/>
            <Setter Property="Foreground"      Value="#E2E8F0"/>
            <Setter Property="CaretBrush"      Value="#3B82F6"/>
            <Setter Property="BorderBrush"     Value="#2D3252"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="10,7"/>
            <Setter Property="FontSize"        Value="12"/>
            <Setter Property="FontFamily"      Value="Consolas"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ScrollViewer x:Name="PART_ContentHost"
                                          Padding="{TemplateBinding Padding}"
                                          VerticalScrollBarVisibility="Auto"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter Property="BorderBrush" Value="#3B82F6"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ComboBox Style -->
        <Style x:Key="StyledCombo" TargetType="ComboBox">
            <Setter Property="Background"      Value="#21253A"/>
            <Setter Property="Foreground"      Value="#E2E8F0"/>
            <Setter Property="BorderBrush"     Value="#2D3252"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="10,7"/>
            <Setter Property="FontSize"        Value="12"/>
        </Style>

        <!-- DataGrid Style -->
        <Style x:Key="ResultGrid" TargetType="DataGrid">
            <Setter Property="Background"            Value="#1A1D27"/>
            <Setter Property="Foreground"            Value="#E2E8F0"/>
            <Setter Property="BorderBrush"           Value="#2D3252"/>
            <Setter Property="BorderThickness"       Value="1"/>
            <Setter Property="GridLinesVisibility"   Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#2D3252"/>
            <Setter Property="RowBackground"         Value="#1A1D27"/>
            <Setter Property="AlternatingRowBackground" Value="#1E2235"/>
            <Setter Property="FontSize"              Value="12"/>
            <Setter Property="AutoGenerateColumns"   Value="True"/>
            <Setter Property="IsReadOnly"            Value="True"/>
            <Setter Property="SelectionMode"         Value="Single"/>
            <Setter Property="HeadersVisibility"     Value="Column"/>
            <Setter Property="CanUserResizeRows"     Value="False"/>
            <Setter Property="ColumnHeaderStyle">
                <Setter.Value>
                    <Style TargetType="DataGridColumnHeader">
                        <Setter Property="Background"  Value="#21253A"/>
                        <Setter Property="Foreground"  Value="#8892AA"/>
                        <Setter Property="Padding"     Value="10,6"/>
                        <Setter Property="FontSize"    Value="11"/>
                        <Setter Property="FontWeight"  Value="SemiBold"/>
                        <Setter Property="BorderBrush" Value="#2D3252"/>
                        <Setter Property="BorderThickness" Value="0,0,0,1"/>
                    </Style>
                </Setter.Value>
            </Setter>
            <Setter Property="CellStyle">
                <Setter.Value>
                    <Style TargetType="DataGridCell">
                        <Setter Property="BorderThickness" Value="0"/>
                        <Setter Property="Padding"         Value="10,5"/>
                        <Setter Property="Foreground"      Value="#E2E8F0"/>
                        <Style.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter Property="Background" Value="#2D3252"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="220"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- ── SIDEBAR ── -->
        <Border Grid.Column="0" Background="#1A1D27"
                BorderBrush="#2D3252" BorderThickness="0,0,1,0">
            <DockPanel>
                <!-- Logo / Title -->
                <StackPanel DockPanel.Dock="Top" Margin="16,24,16,20">
                    <TextBlock Text="⚡ EpmTools" FontSize="18" FontWeight="Bold"
                               Foreground="#E2E8F0"/>
                    <TextBlock Text="Endpoint Privilege Management"
                               FontSize="10" Foreground="#4B5563" Margin="0,3,0,0"
                               TextWrapping="Wrap"/>
                </StackPanel>

                <!-- Module Status -->
                <Border DockPanel.Dock="Top" Margin="12,0,12,16"
                        Background="#21253A" CornerRadius="8" Padding="12,10">
                    <StackPanel>
                        <TextBlock Text="MODULE STATUS" FontSize="9" FontWeight="Bold"
                                   Foreground="#4B5563"
                                   Margin="0,0,0,6"/>
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Ellipse x:Name="StatusDot" Width="8" Height="8"
                                     Fill="#EF4444" Margin="0,0,8,0"
                                     VerticalAlignment="Center"/>
                            <TextBlock x:Name="StatusText" Text="Not Loaded"
                                       FontSize="12" Foreground="#8892AA"
                                       VerticalAlignment="Center"/>
                        </StackPanel>
                    </StackPanel>
                </Border>

                <!-- Navigation -->
                <StackPanel DockPanel.Dock="Top" Margin="8,0">
                    <TextBlock Text="CMDLETS" FontSize="9" FontWeight="Bold"
                               Foreground="#4B5563" Margin="12,0,0,8"/>

                    <RadioButton x:Name="navHome" Style="{StaticResource NavButton}"
                                 IsChecked="True">Dashboard</RadioButton>

                    <RadioButton x:Name="navPolicies" Style="{StaticResource NavButton}">Get-Policies</RadioButton>

                    <RadioButton x:Name="navDeclaredConfig" Style="{StaticResource NavButton}">Get-DeclaredConfiguration</RadioButton>

                    <RadioButton x:Name="navDeclaredAnalysis" Style="{StaticResource NavButton}">Get-DeclaredConfigurationAnalysis</RadioButton>

                    <RadioButton x:Name="navElevationRules" Style="{StaticResource NavButton}">Get-ElevationRules</RadioButton>

                    <RadioButton x:Name="navClientSettings" Style="{StaticResource NavButton}">Get-ClientSettings</RadioButton>

                    <RadioButton x:Name="navFileAttributes" Style="{StaticResource NavButton}">Get-FileAttributes</RadioButton>
                </StackPanel>

                <!-- Load module button at bottom -->
                <StackPanel DockPanel.Dock="Bottom" Margin="12,0,12,16">
                    <Separator Background="#2D3252" Margin="0,0,0,12"/>
                    <Button x:Name="btnLoadModule" Style="{StaticResource ActionButton}"
                            Content="⚡  Load EpmTools Module" Padding="12,9"
                            FontSize="12"/>
                    <Button x:Name="btnClearOutput" Style="{StaticResource SecondaryButton}"
                            Content="🗑  Clear Output" Padding="12,9"
                            FontSize="12" Margin="0,6,0,0"/>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- ── MAIN CONTENT ── -->
        <Grid Grid.Column="1" Background="#0F1117">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="400"/>
            </Grid.RowDefinitions>

            <!-- Top Bar -->
            <Border Grid.Row="0" Background="#1A1D27"
                    BorderBrush="#2D3252" BorderThickness="0,0,0,1"
                    Padding="20,14">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="PageTitle" Text="Dashboard"
                                   FontSize="18" FontWeight="SemiBold"
                                   Foreground="#E2E8F0"/>
                        <TextBlock x:Name="PageSubtitle"
                                   Text="EPM module overview and quick actions"
                                   FontSize="12" Foreground="#8892AA" Margin="0,2,0,0"/>
                    </StackPanel>
                    <TextBlock Grid.Column="1" x:Name="ClockText"
                               FontSize="11" Foreground="#4B5563"
                               VerticalAlignment="Center" FontFamily="Consolas"/>
                </Grid>
            </Border>

            <!-- Page Content (Cards / Panels) -->
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                          Background="#0F1117">
                <Grid Margin="20">

                    <!-- ── PAGE: Dashboard ── -->
                    <StackPanel x:Name="panelHome">
                        <!-- Info Cards -->
                        <Grid Margin="0,0,0,16">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <!-- Card 1 -->
                            <Border Grid.Column="0" Background="#21253A"
                                    CornerRadius="10" Padding="16" Margin="0,0,8,0">
                                <StackPanel>
                                    <TextBlock Text="📋" FontSize="22" Margin="0,0,0,8"/>
                                    <TextBlock Text="EPM Policies" FontSize="13"
                                               FontWeight="SemiBold" Foreground="#E2E8F0"/>
                                    <TextBlock Text="Retrieve ElevationRules or ClientSettings policies from the EPM Agent."
                                               FontSize="11" Foreground="#8892AA"
                                               TextWrapping="Wrap" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                            <!-- Card 2 -->
                            <Border Grid.Column="1" Background="#21253A"
                                    CornerRadius="10" Padding="16" Margin="4,0,4,0">
                                <StackPanel>
                                    <TextBlock Text="🛡️" FontSize="22" Margin="0,0,0,8"/>
                                    <TextBlock Text="Elevation Rules" FontSize="13"
                                               FontWeight="SemiBold" Foreground="#E2E8F0"/>
                                    <TextBlock Text="Query EPM Agent lookup for rules by FileName or CertificatePayload."
                                               FontSize="11" Foreground="#8892AA"
                                               TextWrapping="Wrap" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                            <!-- Card 3 -->
                            <Border Grid.Column="2" Background="#21253A"
                                    CornerRadius="10" Padding="16" Margin="8,0,0,0">
                                <StackPanel>
                                    <TextBlock Text="📁" FontSize="22" Margin="0,0,0,8"/>
                                    <TextBlock Text="File Attributes" FontSize="13"
                                               FontWeight="SemiBold" Foreground="#E2E8F0"/>
                                    <TextBlock Text="Extract publisher and CA certificates from .exe files for rule building."
                                               FontSize="11" Foreground="#8892AA"
                                               TextWrapping="Wrap" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- Getting Started -->
                        <Border Background="#21253A" CornerRadius="10" Padding="20">
                            <StackPanel>
                                <TextBlock Text="Getting Started" FontSize="14"
                                           FontWeight="SemiBold" Foreground="#E2E8F0"
                                           Margin="0,0,0,12"/>
                                <StackPanel Margin="0,0,0,8">
                                    <TextBlock FontSize="12" Foreground="#8892AA" TextWrapping="Wrap">
                                        <Run Foreground="#3B82F6" FontWeight="SemiBold">1.</Run>
                                        <Run> Click </Run>
                                        <Run Foreground="#E2E8F0" FontWeight="SemiBold">⚡ Load EpmTools Module</Run>
                                        <Run> in the sidebar to import EpmCmdlets.dll from the EPM Agent.</Run>
                                    </TextBlock>
                                </StackPanel>
                                <StackPanel Margin="0,0,0,8">
                                    <TextBlock FontSize="12" Foreground="#8892AA" TextWrapping="Wrap">
                                        <Run Foreground="#3B82F6" FontWeight="SemiBold">2.</Run>
                                        <Run> Navigate to a cmdlet tab, configure parameters, and click </Run>
                                        <Run Foreground="#E2E8F0" FontWeight="SemiBold">Run</Run>
                                        <Run>.</Run>
                                    </TextBlock>
                                </StackPanel>
                                <StackPanel>
                                    <TextBlock FontSize="12" Foreground="#8892AA" TextWrapping="Wrap">
                                        <Run Foreground="#3B82F6" FontWeight="SemiBold">3.</Run>
                                        <Run> Results appear in the grid above the output console. Use </Run>
                                        <Run Foreground="#E2E8F0" FontWeight="SemiBold">Export CSV</Run>
                                        <Run> to save data.</Run>
                                    </TextBlock>
                                </StackPanel>

                                <Separator Background="#2D3252" Margin="0,16"/>

                                <TextBlock Text="Module path:" FontSize="11"
                                           Foreground="#4B5563" Margin="0,0,0,4"/>
                                <TextBlock Text="C:\Program Files\Microsoft EPM Agent\EpmTools\EpmCmdlets.dll"
                                           FontSize="11" FontFamily="Consolas"
                                           Foreground="#22C55E" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>

                    <!-- ── PAGE: Get-Policies ── -->
                    <Border x:Name="panelPolicies" Visibility="Collapsed"
                            Background="#21253A" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Select policy type to retrieve:" FontSize="12"
                                       Foreground="#8892AA" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                                <RadioButton x:Name="rbElevationRules"
                                             Content="ElevationRules" IsChecked="True"
                                             Foreground="#E2E8F0" FontSize="12"
                                             GroupName="PolicyType" Margin="0,0,20,0"/>
                                <RadioButton x:Name="rbClientSettings"
                                             Content="ClientSettings"
                                             Foreground="#E2E8F0" FontSize="12"
                                             GroupName="PolicyType"/>
                            </StackPanel>
                            <Button x:Name="btnRunGetPolicies"
                                    Style="{StaticResource ActionButton}"
                                    Content="▶  Run Get-Policies"
                                    HorizontalAlignment="Left" Padding="16,9"/>
                        </StackPanel>
                    </Border>

                    <!-- ── PAGE: Get-DeclaredConfiguration ── -->
                    <Border x:Name="panelDeclaredConfig" Visibility="Collapsed"
                            Background="#21253A" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Retrieves all WinDC documents identifying policies targeted to this device."
                                       FontSize="12" Foreground="#8892AA" TextWrapping="Wrap"
                                       Margin="0,0,0,12"/>

                            <TextBlock Text="Policy Type:" FontSize="11" Foreground="#4B5563" Margin="0,0,0,6"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                                <RadioButton x:Name="rbDeclaredElevationRules"
                                             Content="ElevationRules" IsChecked="True"
                                             Foreground="#E2E8F0" FontSize="12"
                                             GroupName="DeclaredPolicyType" Margin="0,0,12,0"/>
                                <RadioButton x:Name="rbDeclaredClientSettings"
                                             Content="ClientSettings"
                                             Foreground="#E2E8F0" FontSize="12"
                                             GroupName="DeclaredPolicyType"/>
                            </StackPanel>

                            <Button x:Name="btnRunDeclaredConfig"
                                    Style="{StaticResource ActionButton}"
                                    Content="▶  Run Get-DeclaredConfiguration"
                                    HorizontalAlignment="Left" Padding="16,9" Margin="0,12,0,0"/>
                        </StackPanel>
                    </Border>

                    <!-- ── PAGE: Get-DeclaredConfigurationAnalysis ── -->
                    <Border x:Name="panelDeclaredAnalysis" Visibility="Collapsed"
                            Background="#21253A" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Retrieves WinDC documents of type MSFTPolicies and checks if each policy is present in the EPM Agent (Processed column)."
                                       FontSize="12" Foreground="#8892AA" TextWrapping="Wrap"
                                       Margin="0,0,0,12"/>

                            <TextBlock Text="Policy Type:" FontSize="11" Foreground="#4B5563" Margin="0,0,0,6"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                                <RadioButton x:Name="rbAnalysisElevationRules"
                                             Content="ElevationRules" IsChecked="True"
                                             Foreground="#E2E8F0" FontSize="12"
                                             GroupName="AnalysisPolicyType" Margin="0,0,12,0"/>
                                <RadioButton x:Name="rbAnalysisClientSettings"
                                             Content="ClientSettings"
                                             Foreground="#E2E8F0" FontSize="12"
                                             GroupName="AnalysisPolicyType"/>
                            </StackPanel>

                            <Button x:Name="btnRunDeclaredAnalysis"
                                    Style="{StaticResource ActionButton}"
                                    Content="▶  Run Get-DeclaredConfigurationAnalysis"
                                    HorizontalAlignment="Left" Padding="16,9"/>
                        </StackPanel>
                    </Border>

                    <!-- ── PAGE: Get-ElevationRules ── -->
                    <Border x:Name="panelElevationRules" Visibility="Collapsed"
                            Background="#21253A" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Lookup type:" FontSize="12"
                                       Foreground="#8892AA" Margin="0,0,0,6"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                                <RadioButton x:Name="rbLookupFileName"
                                             Content="FileName" IsChecked="True"
                                             Foreground="#E2E8F0" FontSize="12"
                                             GroupName="LookupType" Margin="0,0,20,0"/>
                                <RadioButton x:Name="rbLookupCert"
                                             Content="CertificatePayload"
                                             Foreground="#E2E8F0" FontSize="12"
                                             GroupName="LookupType"/>
                            </StackPanel>

                            <TextBlock Text="Target value (file name or certificate payload):"
                                       FontSize="12" Foreground="#8892AA" Margin="0,0,0,6"/>
                            <TextBox x:Name="txtElevationTarget"
                                     Style="{StaticResource InputBox}"
                                     Height="36" Margin="0,0,0,16"
                                     ToolTip="e.g. notepad.exe"/>

                            <Button x:Name="btnRunElevationRules"
                                    Style="{StaticResource ActionButton}"
                                    Content="▶  Run Get-ElevationRules"
                                    HorizontalAlignment="Left" Padding="16,9"/>
                        </StackPanel>
                    </Border>

                    <!-- ── PAGE: Get-ClientSettings ── -->
                    <Border x:Name="panelClientSettings" Visibility="Collapsed"
                            Background="#21253A" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Processes all existing client settings policies to display the effective settings used by EPM on this device."
                                       FontSize="12" Foreground="#8892AA" TextWrapping="Wrap"
                                       Margin="0,0,0,16"/>
                            <Button x:Name="btnRunClientSettings"
                                    Style="{StaticResource ActionButton}"
                                    Content="▶  Run Get-ClientSettings"
                                    HorizontalAlignment="Left" Padding="16,9"/>
                        </StackPanel>
                    </Border>

                    <!-- ── PAGE: Get-FileAttributes ── -->
                    <Border x:Name="panelFileAttributes" Visibility="Collapsed"
                            Background="#21253A" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Select an .exe file to extract its publisher and CA certificates:"
                                       FontSize="12" Foreground="#8892AA" Margin="0,0,0,8"/>

                            <Grid Margin="0,0,0,16">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="txtExePath"
                                         Style="{StaticResource InputBox}"
                                         Grid.Column="0" Height="36"
                                         IsReadOnly="True"
                                         Text="No file selected…"
                                         Foreground="#4B5563"/>
                                <Button x:Name="btnBrowseExe"
                                        Style="{StaticResource SecondaryButton}"
                                        Grid.Column="1" Content="Browse…"
                                        Padding="14,9" Margin="8,0,0,0"/>
                            </Grid>

                            <TextBlock Text="Output folder for extracted certificates:"
                                       FontSize="12" Foreground="#8892AA" Margin="0,0,0,8"/>
                            <Grid Margin="0,0,0,16">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="txtCertOutput"
                                         Style="{StaticResource InputBox}"
                                         Grid.Column="0" Height="36"
                                         Text="C:\Temp\EpmCerts"/>
                                <Button x:Name="btnBrowseCertFolder"
                                        Style="{StaticResource SecondaryButton}"
                                        Grid.Column="1" Content="Browse…"
                                        Padding="14,9" Margin="8,0,0,0"/>
                            </Grid>

                            <Button x:Name="btnRunFileAttributes"
                                    Style="{StaticResource ActionButton}"
                                    Content="▶  Run Get-FileAttributes"
                                    HorizontalAlignment="Left" Padding="16,9"/>
                        </StackPanel>
                    </Border>

                </Grid>
            </ScrollViewer>

            <!-- ── OUTPUT / RESULTS PANE ── -->
            <Grid Grid.Row="2" Background="#0F1117">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <!-- Results Toolbar -->
                <Border Grid.Row="0" Background="#1A1D27"
                        BorderBrush="#2D3252" BorderThickness="0,1,0,0"
                        Padding="16,8">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock x:Name="ResultLabel" Text="Output Console"
                                   FontSize="11" FontWeight="SemiBold"
                                   Foreground="#8892AA" VerticalAlignment="Center"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                            <Button x:Name="btnExportCsv"
                                    Style="{StaticResource SecondaryButton}"
                                    Content="📤 Export CSV"
                                    Padding="10,6" FontSize="11"
                                    Margin="0,0,8,0" IsEnabled="False"/>
                            <Button x:Name="btnExportJson"
                                    Style="{StaticResource SecondaryButton}"
                                    Content="&#123;&#125; Export JSON"
                                    Padding="10,6" FontSize="11"
                                    IsEnabled="False"/>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- Tab: Grid vs Log -->
                <TabControl Grid.Row="1" Background="#0F1117"
                            BorderBrush="#2D3252" BorderThickness="0">
                    <TabControl.Resources>
                        <Style TargetType="TabItem">
                            <Setter Property="Background"  Value="#1A1D27"/>
                            <Setter Property="Foreground"  Value="#8892AA"/>
                            <Setter Property="Padding"     Value="12,6"/>
                            <Setter Property="FontSize"    Value="11"/>
                            <Setter Property="BorderThickness" Value="0"/>
                            <Style.Triggers>
                                <Trigger Property="IsSelected" Value="True">
                                    <Setter Property="Background" Value="#21253A"/>
                                    <Setter Property="Foreground" Value="#E2E8F0"/>
                                </Trigger>
                            </Style.Triggers>
                        </Style>
                    </TabControl.Resources>

                    <TabItem Header="📝  Console Log" IsSelected="True">
                        <TextBox x:Name="ConsoleLog"
                                 Background="#0D1117"
                                 Foreground="#22C55E"
                                 FontFamily="Consolas"
                                 FontSize="11"
                                 IsReadOnly="True"
                                 TextWrapping="Wrap"
                                 VerticalScrollBarVisibility="Auto"
                                 HorizontalScrollBarVisibility="Auto"
                                 BorderThickness="0"
                                 Padding="12"/>
                    </TabItem>

                    <TabItem Header="🗒️  Raw Output">
                        <TextBox x:Name="RawOutput"
                                 Background="#0B0E13"
                                 Foreground="#E2E8F0"
                                 FontFamily="Consolas"
                                 FontSize="12"
                                 IsReadOnly="True"
                                 TextWrapping="Wrap"
                                 AcceptsReturn="True"
                                 VerticalScrollBarVisibility="Auto"
                                 HorizontalScrollBarVisibility="Auto"
                                 BorderThickness="0"
                                 Padding="12"/>
                    </TabItem>

                    <TabItem Header="📊  Results Grid">
                        <DataGrid x:Name="ResultGrid"
                                  Style="{StaticResource ResultGrid}"
                                  Margin="0"/>
                    </TabItem>
                </TabControl>
            </Grid>
        </Grid>
    </Grid>
</Window>
"@

# -------------------------------------------------------------
# Build Window
# -------------------------------------------------------------
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$script:ModuleLoaded = $false
$script:LastResults  = $null

# -------------------------------------------------------------
# Helper functions stored as $script: scriptblock variables.
# This is the ONLY reliable way to call shared logic from
# inside WPF event-handler scriptblocks in Windows PowerShell.
# -------------------------------------------------------------

$script:WriteLog = {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        "OK"    { "[OK]  " }
        "ERR"   { "[ERR] " }
        "WARN"  { "[WARN]" }
        default { "[INFO]" }
    }
    $line = "[$ts] $prefix $Message`n"
    $ctrl = $window.FindName('ConsoleLog')
    if ($ctrl) {
        $ctrl.Dispatcher.Invoke([Action]{
            $ctrl.AppendText($line)
            $ctrl.ScrollToEnd()
        })
    }
}

$script:SetModuleStatus = {
    param([bool]$Loaded)
    if ($Loaded) {
        $window.FindName('StatusDot').Fill        = [System.Windows.Media.Brushes]::LimeGreen
        $window.FindName('StatusText').Text       = "Loaded"
        $window.FindName('StatusText').Foreground = [System.Windows.Media.Brushes]::LimeGreen
    } else {
        $window.FindName('StatusDot').Fill        = [System.Windows.Media.Brushes]::OrangeRed
        $window.FindName('StatusText').Text       = "Not Loaded"
        $window.FindName('StatusText').Foreground = [System.Windows.Media.Brushes]::OrangeRed
    }
}

$script:ShowPanel = {
    param([string]$Name)
    $panels = @(
        'panelHome','panelPolicies','panelDeclaredConfig',
        'panelDeclaredAnalysis','panelElevationRules',
        'panelClientSettings','panelFileAttributes'
    )
    foreach ($p in $panels) {
        $el = $window.FindName($p)
        if ($el) { $el.Visibility = [System.Windows.Visibility]::Collapsed }
    }
    $target = $window.FindName($Name)
    if ($target) { $target.Visibility = [System.Windows.Visibility]::Visible }
}

$script:PopulateGrid = {
    param($Data)
    $grid   = $window.FindName('ResultGrid')
    $btnCsv = $window.FindName('btnExportCsv')
    $btnJs  = $window.FindName('btnExportJson')

    if ($null -eq $Data -or ($Data | Measure-Object).Count -eq 0) {
        $grid.ItemsSource = $null
        & $script:WriteLog "No results returned." "WARN"
        return
    }
    $dt    = New-Object System.Data.DataTable
    $first = $Data | Select-Object -First 1
    $props = $first.PSObject.Properties | Where-Object {
        $_.MemberType -eq 'NoteProperty' -or $_.MemberType -eq 'Property'
    }

    foreach ($p in $props) { [void]$dt.Columns.Add($p.Name) }
    foreach ($item in $Data) {
        $row = $dt.NewRow()
        foreach ($p in $props) {
            $val = $item.$($p.Name)
            $row[$p.Name] = if ($null -eq $val) { "" } else { $val.ToString() }
        }
        $dt.Rows.Add($row)
    }

    $grid.ItemsSource   = $dt.DefaultView
    $btnCsv.IsEnabled   = $true
    $btnJs.IsEnabled    = $true
    $script:LastResults = $Data
    & $script:WriteLog "$($dt.Rows.Count) row(s) returned." "OK"
}

# -------------------------------------------------------------
# Clock Timer
# -------------------------------------------------------------
$timer          = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({ $window.FindName('ClockText').Text = (Get-Date -Format "ddd dd MMM yyyy  HH:mm:ss") })
$timer.Start()

# -------------------------------------------------------------
# Navigation
# -------------------------------------------------------------
$navMap = @{
    'navHome'             = @{ Panel = 'panelHome';             Title = 'Dashboard';                         Sub = 'EPM module overview and quick actions' }
    'navPolicies'         = @{ Panel = 'panelPolicies';         Title = 'Get-Policies';                      Sub = 'Retrieve policies by type from the EPM Agent' }
    'navDeclaredConfig'   = @{ Panel = 'panelDeclaredConfig';   Title = 'Get-DeclaredConfiguration';         Sub = 'List WinDC documents targeted to this device' }
    'navDeclaredAnalysis' = @{ Panel = 'panelDeclaredAnalysis'; Title = 'Get-DeclaredConfigurationAnalysis'; Sub = 'Check which MSFTPolicies are processed by the EPM Agent' }
    'navElevationRules'   = @{ Panel = 'panelElevationRules';   Title = 'Get-ElevationRules';                Sub = 'Query elevation rules by FileName or CertificatePayload' }
    'navClientSettings'   = @{ Panel = 'panelClientSettings';   Title = 'Get-ClientSettings';                Sub = 'Display effective client settings used by EPM' }
    'navFileAttributes'   = @{ Panel = 'panelFileAttributes';   Title = 'Get-FileAttributes';                Sub = 'Extract publisher and CA certs from an .exe for rule building' }
}

foreach ($key in $navMap.Keys) {
    $btn       = $window.FindName($key)
    $panelName = $navMap[$key].Panel
    $title     = $navMap[$key].Title
    $sub       = $navMap[$key].Sub

    $btn.Add_Checked({
        & $script:ShowPanel $panelName
        $window.FindName('PageTitle').Text    = $title
        $window.FindName('PageSubtitle').Text = $sub
    }.GetNewClosure())
}

# -------------------------------------------------------------
# Load Module
# -------------------------------------------------------------
$window.FindName('btnLoadModule').Add_Click({
    $modulePath = 'C:\Program Files\Microsoft EPM Agent\EpmTools\EpmCmdlets.dll'
    & $script:WriteLog "Attempting to load EpmTools from: $modulePath"
    try {
        if (-not (Test-Path $modulePath)) {
            throw "Module file not found at:`n$modulePath`n`nEnsure this device has received EPM policy from Intune."
        }
        Import-Module $modulePath -ErrorAction Stop
        $script:ModuleLoaded = $true
        & $script:SetModuleStatus $true
        & $script:WriteLog "EpmTools module loaded successfully." "OK"
    } catch {
        & $script:SetModuleStatus $false
        $errMsg = $_.Exception.Message
        $hint = if ($errMsg -match 'architect') {
            "`n`nARM64 detected. EpmCmdlets.dll requires Windows PowerShell x64.`nRun: %SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -STA -File EpmTools-GUI.ps1"
        } else { "" }
        & $script:WriteLog "Failed to load module: $errMsg" "ERR"
        [System.Windows.MessageBox]::Show(
            "$errMsg$hint", "Module Load Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error)
    }
})

# -------------------------------------------------------------
# Clear Output
# -------------------------------------------------------------
$window.FindName('btnClearOutput').Add_Click({
    $window.FindName('ConsoleLog').Clear()
    $window.FindName('ResultGrid').ItemsSource  = $null
    $window.FindName('btnExportCsv').IsEnabled  = $false
    $window.FindName('btnExportJson').IsEnabled = $false
    $script:LastResults = $null
})

# -------------------------------------------------------------
# Get-Policies
# -------------------------------------------------------------
$window.FindName('btnRunGetPolicies').Add_Click({
    if (-not $script:ModuleLoaded) { & $script:WriteLog "Module not loaded. Click 'Load EpmTools Module' first." "WARN"; return }
    $policyType = if ($window.FindName('rbElevationRules').IsChecked) { 'ElevationRules' } else { 'ClientSettings' }
    & $script:WriteLog "Running: Get-Policies -PolicyType $policyType -Verbose"
    try {
        $SavedVerbosePreference = $VerbosePreference
        $VerbosePreference = 'Continue'

        $allOutput = Get-Policies -PolicyType $policyType -ErrorAction Stop -Verbose 4>&1

        $data = @()
        foreach ($obj in $allOutput) {
            if ($obj -is [System.Management.Automation.VerboseRecord]) {
                & $script:WriteLog "VERBOSE: $($obj.Message)" "INFO"
            } else {
                $data += $obj
            }
        }

        $VerbosePreference = $SavedVerbosePreference

        if ($data.Count -gt 0) {
            & $script:PopulateGrid $data
            try {
                $json = $data | ConvertTo-Json -Depth 10
                $raw  = $json | Out-String -Width 4096
            } catch {
                $raw = $data | Out-String
            }
            $window.FindName('RawOutput').Text = $raw.TrimEnd()
        } else {
            & $script:WriteLog "No data returned." "WARN"
            $window.FindName('RawOutput').Text = ""
        }
    } catch {
        & $script:WriteLog "Error: $($_.Exception.Message)" "ERR"
    }
})

# -------------------------------------------------------------
# Get-DeclaredConfiguration
# -------------------------------------------------------------
$window.FindName('btnRunDeclaredConfig').Add_Click({
    if (-not $script:ModuleLoaded) { & $script:WriteLog "Module not loaded." "WARN"; return }
    $policyType = if ($window.FindName('rbDeclaredElevationRules').IsChecked) { 'ElevationRules' } else { 'ClientSettings' }
    & $script:WriteLog "Running: Get-DeclaredConfiguration -PolicyType $policyType -Verbose"
    try {
        # Ensure verbose messages are produced
        $SavedVerbosePreference = $VerbosePreference
        $VerbosePreference = 'Continue'

        $allOutput = Get-DeclaredConfiguration -PolicyType $policyType -ErrorAction Stop -Verbose 4>&1

        # Separate verbose records from data objects
        $data = @()
        foreach ($obj in $allOutput) {
            if ($obj -is [System.Management.Automation.VerboseRecord]) {
                & $script:WriteLog "VERBOSE: $($obj.Message)" "INFO"
            } else {
                $data += $obj
            }
        }

        $VerbosePreference = $SavedVerbosePreference

        if ($data.Count -gt 0) {
            & $script:PopulateGrid $data
            try {
                $json = $data | ConvertTo-Json -Depth 10
                $raw  = $json | Out-String -Width 4096
            } catch {
                $raw = $data | Out-String
            }
            $window.FindName('RawOutput').Text = $raw.TrimEnd()
        } else {
            & $script:WriteLog "No data returned." "WARN"
            $window.FindName('RawOutput').Text = ""
        }
    } catch {
        & $script:WriteLog "Error: $($_.Exception.Message)" "ERR"
    }
})

# -------------------------------------------------------------
# Get-DeclaredConfigurationAnalysis
# -------------------------------------------------------------
$window.FindName('btnRunDeclaredAnalysis').Add_Click({
    if (-not $script:ModuleLoaded) { & $script:WriteLog "Module not loaded." "WARN"; return }
    $policyType = if ($window.FindName('rbAnalysisElevationRules').IsChecked) { 'ElevationRules' } else { 'ClientSettings' }
    & $script:WriteLog "Running: Get-DeclaredConfigurationAnalysis -PolicyType $policyType -Verbose"
    try {
        $SavedVerbosePreference = $VerbosePreference
        $VerbosePreference = 'Continue'

        $allOutput = Get-DeclaredConfigurationAnalysis -PolicyType $policyType -ErrorAction Stop -Verbose 4>&1

        $data = @()
        foreach ($obj in $allOutput) {
            if ($obj -is [System.Management.Automation.VerboseRecord]) {
                & $script:WriteLog "VERBOSE: $($obj.Message)" "INFO"
            } else {
                $data += $obj
            }
        }

        $VerbosePreference = $SavedVerbosePreference

        if ($data.Count -gt 0) {
            & $script:PopulateGrid $data
            try {
                $json = $data | ConvertTo-Json -Depth 10
                $raw  = $json | Out-String -Width 4096
            } catch {
                $raw = $data | Out-String
            }
            $window.FindName('RawOutput').Text = $raw.TrimEnd()
        } else {
            & $script:WriteLog "No data returned." "WARN"
            $window.FindName('RawOutput').Text = ""
        }
    } catch {
        & $script:WriteLog "Error: $($_.Exception.Message)" "ERR"
    }
})

# -------------------------------------------------------------
# Get-ElevationRules
# -------------------------------------------------------------
$window.FindName('btnRunElevationRules').Add_Click({
    if (-not $script:ModuleLoaded) { & $script:WriteLog "Module not loaded." "WARN"; return }
    $lookup = if ($window.FindName('rbLookupFileName').IsChecked) { 'FileName' } else { 'CertificatePayload' }
    $target = $window.FindName('txtElevationTarget').Text.Trim()
    if ([string]::IsNullOrEmpty($target)) {
        & $script:WriteLog "Please enter a target value." "WARN"
        return
    }
    & $script:WriteLog "Running: Get-ElevationRules -Lookup $lookup -Target '$target' -Verbose"
    try {
        $SavedVerbosePreference = $VerbosePreference
        $VerbosePreference = 'Continue'

        $allOutput = Get-ElevationRules -Lookup $lookup -Target $target -ErrorAction Stop -Verbose 4>&1

        $data = @()
        foreach ($obj in $allOutput) {
            if ($obj -is [System.Management.Automation.VerboseRecord]) {
                & $script:WriteLog "VERBOSE: $($obj.Message)" "INFO"
            } else {
                $data += $obj
            }
        }

        $VerbosePreference = $SavedVerbosePreference

        if ($data.Count -gt 0) {
            & $script:PopulateGrid $data
            try {
                $json = $data | ConvertTo-Json -Depth 10
                $raw  = $json | Out-String -Width 4096
            } catch {
                $raw = $data | Out-String
            }
            $window.FindName('RawOutput').Text = $raw.TrimEnd()
        } else {
            & $script:WriteLog "No data returned." "WARN"
            $window.FindName('RawOutput').Text = ""
        }
    } catch {
        & $script:WriteLog "Error: $($_.Exception.Message)" "ERR"
    }
})

# -------------------------------------------------------------
# Get-ClientSettings
# -------------------------------------------------------------
$window.FindName('btnRunClientSettings').Add_Click({
    if (-not $script:ModuleLoaded) { & $script:WriteLog "Module not loaded." "WARN"; return }
    & $script:WriteLog "Running: Get-ClientSettings -Verbose"
    try {
        $SavedVerbosePreference = $VerbosePreference
        $VerbosePreference = 'Continue'

        $allOutput = Get-ClientSettings -ErrorAction Stop -Verbose 4>&1

        $result = @()
        foreach ($obj in $allOutput) {
            if ($obj -is [System.Management.Automation.VerboseRecord]) {
                & $script:WriteLog "VERBOSE: $($obj.Message)" "INFO"
            } else {
                $result += $obj
            }
        }

        $VerbosePreference = $SavedVerbosePreference

        # Build a Property | Value row-per-entry grid
        try {
            $dt = New-Object System.Data.DataTable
            [void]$dt.Columns.Add('Property')
            [void]$dt.Columns.Add('Value')

            $items = @($result)
            for ($i = 0; $i -lt $items.Count; $i++) {
                if ($items.Count -gt 1) {
                    $sepRow = $dt.NewRow()
                    $sepRow['Property'] = "-- Item $($i + 1) --"
                    $sepRow['Value']    = ''
                    $dt.Rows.Add($sepRow)
                }
                foreach ($prop in $items[$i].PSObject.Properties) {
                    $row = $dt.NewRow()
                    $row['Property'] = $prop.Name
                    $row['Value']    = if ($null -eq $prop.Value) { '' } else { $prop.Value.ToString() }
                    $dt.Rows.Add($row)
                }
            }

            $grid   = $window.FindName('ResultGrid')
            $btnCsv = $window.FindName('btnExportCsv')
            $btnJs  = $window.FindName('btnExportJson')
            $grid.ItemsSource    = $dt.DefaultView
            $btnCsv.IsEnabled    = $true
            $btnJs.IsEnabled     = $true
            $script:LastResults  = $result
            & $script:WriteLog "$($dt.Rows.Count) propert(ies) displayed." "OK"
        } catch {
            & $script:WriteLog "Grid render failed: $($_.Exception.Message)" "ERR"
            $window.FindName('ResultGrid').ItemsSource = $null
        }

        # Also populate RawOutput with a readable view (keep grid populated)
        try {
            $sb = New-Object System.Text.StringBuilder
            $items = @($result)
            for ($i = 0; $i -lt $items.Count; $i++) {
                $item = $items[$i]
                if ($items.Count -gt 1) { [void]$sb.AppendLine("Item $($i+1):") }
                foreach ($prop in $item.PSObject.Properties) {
                    $val = $prop.Value
                    if ($val -is [string]) {
                        $matches = [regex]::Matches($val, '(\w+)=([^\s]+)')
                        if ($matches.Count -gt 0) {
                            [void]$sb.AppendLine("$($prop.Name):")
                            foreach ($m in $matches) { [void]$sb.AppendLine("  $($m.Groups[1].Value): $($m.Groups[2].Value)") }
                            continue
                        }
                    }

                    if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                        $jsonVal = $val | ConvertTo-Json -Depth 5
                        [void]$sb.AppendLine("$($prop.Name):")
                        foreach ($ln in ($jsonVal -split '\r?\n')) { [void]$sb.AppendLine("  $ln") }
                    } else {
                        $display = if ($null -eq $val) { '' } else { $val.ToString() }
                        [void]$sb.AppendLine("$($prop.Name): $display")
                    }
                }
                [void]$sb.AppendLine('')
            }
            $pretty = $sb.ToString().TrimEnd()
        } catch {
            try { $pretty = ($result | ConvertTo-Json -Depth 10) | Out-String -Width 4096 } catch { $pretty = $result | Out-String }
        }
        $window.FindName('RawOutput').Text = $pretty

        & $script:WriteLog "--- Get-ClientSettings output ---" "OK"
        $ctrl = $window.FindName('ConsoleLog')
        $ctrl.Dispatcher.Invoke([Action]{
            $ctrl.AppendText($pretty + "`n")
            $ctrl.ScrollToEnd()
        })
        & $script:WriteLog "--- end of output ---" "OK"
    } catch {
        & $script:WriteLog "Error: $($_.Exception.Message)" "ERR"
    }
})

# -------------------------------------------------------------
# Get-FileAttributes
# -------------------------------------------------------------
$window.FindName('btnBrowseExe').Add_Click({
    $ofd        = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.Title  = "Select an executable"
    $ofd.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $window.FindName('txtExePath').Text       = $ofd.FileName
        $window.FindName('txtExePath').Foreground = [System.Windows.Media.Brushes]::White
    }
})

$window.FindName('btnBrowseCertFolder').Add_Click({
    $fbd                     = [System.Windows.Forms.FolderBrowserDialog]::new()
    $fbd.Description         = "Select output folder for extracted certificates"
    $fbd.SelectedPath        = $window.FindName('txtCertOutput').Text
    $fbd.ShowNewFolderButton = $true
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $window.FindName('txtCertOutput').Text = $fbd.SelectedPath
    }
})

$window.FindName('btnRunFileAttributes').Add_Click({
    if (-not $script:ModuleLoaded) { & $script:WriteLog "Module not loaded." "WARN"; return }
    $exePath    = $window.FindName('txtExePath').Text.Trim()
    $certOutput = $window.FindName('txtCertOutput').Text.Trim()

    if ([string]::IsNullOrEmpty($exePath) -or $exePath -eq 'No file selected...') {
        & $script:WriteLog "Please select an .exe file first." "WARN"; return
    }
    if (-not (Test-Path $exePath)) {
        & $script:WriteLog "File not found: $exePath" "ERR"; return
    }
    if (-not (Test-Path $certOutput)) {
        try { New-Item -ItemType Directory -Path $certOutput -Force | Out-Null }
        catch { & $script:WriteLog "Cannot create output folder: $_" "ERR"; return }
    }

    # Auto-discover real parameter names from the loaded cmdlet.
    # The EpmTools readme is vague; parameter names vary by agent version.
    $cmdMeta = Get-Command Get-FileAttributes -ErrorAction SilentlyContinue
    if ($null -eq $cmdMeta) {
        & $script:WriteLog "Get-FileAttributes not found. Is the module loaded?" "ERR"
        return
    }
    $paramNames = $cmdMeta.Parameters.Keys
    & $script:WriteLog "Get-FileAttributes available parameters: $($paramNames -join ', ')" "INFO"

    # Match the exe/file input parameter
    $fileParam = @('FilePath','File','Path','FileName','Exe','ExePath') |
                     Where-Object { $paramNames -contains $_ } | Select-Object -First 1

    # Match the certificate output folder parameter
    $outParam  = @('OutputDirectory','OutputFolder','OutputPath','CertificatePath',
                   'CertPath','Destination','Output','CertOutputPath','ExtractPath') |
                     Where-Object { $paramNames -contains $_ } | Select-Object -First 1

    if (-not $fileParam) {
        & $script:WriteLog "Cannot identify the file input parameter. Please check the console for available parameter names and report them." "ERR"
        return
    }

    $logLine = "Running: Get-FileAttributes -FilePath '$exePath' -Verbose"
    if ($outParam) { $logLine += " -$outParam '$certOutput'" }
    & $script:WriteLog $logLine

    try {
        # Use the explicit FilePath parameter for a lightweight call (enable verbose)
        $splat = @{ FilePath = $exePath; ErrorAction = 'Stop'; Verbose = $true }
        if ($outParam) { $splat[$outParam] = $certOutput }

        # Call the cmdlet and capture verbose records by redirecting stream 4 to output
        $allOutput = & Get-FileAttributes @splat 4>&1

        # Separate verbose records from data objects and emit verbose messages to the ConsoleLog
        $data = @()
        foreach ($obj in $allOutput) {
            if ($obj -is [System.Management.Automation.VerboseRecord]) {
                & $script:WriteLog "VERBOSE: $($obj.Message)" "INFO"
            } else {
                $data += $obj
            }
        }

        if ($data.Count -eq 0) {
            if ($allOutput -and ($allOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })) {
                & $script:WriteLog "No data objects returned; verbose messages displayed above." "WARN"
            } else {
                & $script:WriteLog "No results returned." "WARN"
            }
            $window.FindName('ResultGrid').ItemsSource = $null
            $window.FindName('RawOutput').Text = ''
        } else {
            $resultArray = @($data)

            # Build a Property | Value row-per-entry grid
            try {
                $dt = New-Object System.Data.DataTable
                [void]$dt.Columns.Add('Property')
                [void]$dt.Columns.Add('Value')

                for ($i = 0; $i -lt $resultArray.Count; $i++) {
                    if ($resultArray.Count -gt 1) {
                        $sepRow = $dt.NewRow()
                        $sepRow['Property'] = "-- Item $($i + 1) --"
                        $sepRow['Value']    = ''
                        $dt.Rows.Add($sepRow)
                    }
                    foreach ($prop in $resultArray[$i].PSObject.Properties) {
                        $row = $dt.NewRow()
                        $row['Property'] = $prop.Name
                        $row['Value']    = if ($null -eq $prop.Value) { '' } else { $prop.Value.ToString() }
                        $dt.Rows.Add($row)
                    }
                }

                $grid   = $window.FindName('ResultGrid')
                $btnCsv = $window.FindName('btnExportCsv')
                $btnJs  = $window.FindName('btnExportJson')
                $grid.ItemsSource    = $dt.DefaultView
                $btnCsv.IsEnabled    = $true
                $btnJs.IsEnabled     = $true
                $script:LastResults  = $resultArray
                & $script:WriteLog "$($dt.Rows.Count) propert(ies) displayed." "OK"
            } catch {
                & $script:WriteLog "Grid render failed: $($_.Exception.Message)" "ERR"
                $window.FindName('ResultGrid').ItemsSource = $null
            }

            try {
                $json = $resultArray | ConvertTo-Json -Depth 10 -ErrorAction Stop
                $raw  = $json | Out-String -Width 4096
            } catch {
                try { $raw = $resultArray | Out-String } catch { $raw = 'Unable to render output.' }
            }
            $window.FindName('RawOutput').Text = $raw.TrimEnd()

            if ($outParam) { & $script:WriteLog "Certificates extracted to: $certOutput" "OK" } else { & $script:WriteLog "Done." "OK" }
        }
    } catch {
        & $script:WriteLog "Error: $($_.Exception.Message)" "ERR"
        & $script:WriteLog "All available parameters: $($paramNames -join ', ')" "INFO"
    }
})

# -------------------------------------------------------------
# Export CSV / JSON
# -------------------------------------------------------------
$window.FindName('btnExportCsv').Add_Click({
    if ($null -eq $script:LastResults) { return }
    $sfd          = [System.Windows.Forms.SaveFileDialog]::new()
    $sfd.Filter   = "CSV Files (*.csv)|*.csv"
    $sfd.FileName = "EpmTools-Export-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:LastResults | Export-Csv -Path $sfd.FileName -NoTypeInformation -Encoding UTF8
        & $script:WriteLog "Exported CSV to: $($sfd.FileName)" "OK"
    }
})

$window.FindName('btnExportJson').Add_Click({
    if ($null -eq $script:LastResults) { return }
    $sfd          = [System.Windows.Forms.SaveFileDialog]::new()
    $sfd.Filter   = "JSON Files (*.json)|*.json"
    $sfd.FileName = "EpmTools-Export-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:LastResults | ConvertTo-Json -Depth 10 | Set-Content -Path $sfd.FileName -Encoding UTF8
        & $script:WriteLog "Exported JSON to: $($sfd.FileName)" "OK"
    }
})

# -------------------------------------------------------------
# Start
# -------------------------------------------------------------
& $script:WriteLog "EpmTools GUI started. Click 'Load EpmTools Module' to begin."
& $script:WriteLog "Process architecture: $([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)"

[void]$window.ShowDialog()
