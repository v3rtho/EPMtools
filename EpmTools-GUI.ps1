#Requires -Version 5.1
<#
.SYNOPSIS
    WPF GUI Wrapper for the EpmTools PowerShell Module
    (Microsoft Endpoint Privilege Management)
.NOTES
    Requires EPM policy deployed via Microsoft Intune.
    Module: C:\Program Files\Microsoft EPM Agent\EpmTools\EpmCmdlets.dll
    ARM64 devices: automatically relaunched under Windows PowerShell x64.

    INTUNE > Create Rule / Rule Policies
    Builds EPM elevation rules and pushes them to Intune elevation rules
    policies (Settings Catalog) through Microsoft Graph (beta).
    Needs: DeviceManagementConfiguration.ReadWrite.All (+ Group.Read.All for
    assigning a new policy to a group). Admin consent may be required.
    The EPM agent / EpmCmdlets.dll is NOT required for creating rules.
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

# Windows PowerShell 5.1: some modules add an ETS 'Count' property to arrays,
# which makes ConvertTo-Json emit {"value":[...],"Count":n}. Graph rejects that.
Remove-TypeData System.Array -ErrorAction SilentlyContinue

# -------------------------------------------------------------
# XAML
# -------------------------------------------------------------
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="EpmTools — Endpoint Privilege Management"
    Height="900" Width="1280"
    MinHeight="700" MinWidth="980"
    WindowStartupLocation="CenterScreen"
    Background="#17181C"
    Foreground="#E8E6E1"
    FontFamily="Segoe UI">

    <Window.Resources>
        <!-- Colours -->
        <SolidColorBrush x:Key="PrimaryBg"     Color="#17181C"/>
        <SolidColorBrush x:Key="SurfaceBg"     Color="#1F2023"/>
        <SolidColorBrush x:Key="CardBg"        Color="#26272B"/>
        <SolidColorBrush x:Key="AccentBlue"    Color="#C97B3D"/>
        <SolidColorBrush x:Key="AccentGreen"   Color="#5FA88A"/>
        <SolidColorBrush x:Key="AccentOrange"  Color="#D9A441"/>
        <SolidColorBrush x:Key="AccentRed"     Color="#C1554A"/>
        <SolidColorBrush x:Key="BorderColor"   Color="#35363B"/>
        <SolidColorBrush x:Key="TextPrimary"   Color="#E8E6E1"/>
        <SolidColorBrush x:Key="TextSecondary" Color="#A3A29E"/>
        <SolidColorBrush x:Key="TextMuted"     Color="#6B6A66"/>

        <!-- Button Style -->
        <Style x:Key="ActionButton" TargetType="Button">
            <Setter Property="Background"   Value="#C97B3D"/>
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
                                <Setter Property="Background" Value="#B2692F"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#9C5827"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Background" Value="#3A3B40"/>
                                <Setter Property="Foreground" Value="#7A7975"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Secondary Button -->
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource ActionButton}">
            <Setter Property="Background" Value="#35363B"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3D3E45"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Danger Button -->
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource ActionButton}">
            <Setter Property="Background" Value="#6B3630"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#7D453C"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Nav Button -->
        <Style x:Key="NavButton" TargetType="RadioButton">
            <Setter Property="Background"       Value="Transparent"/>
            <Setter Property="Foreground"       Value="#A3A29E"/>
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
                                <Setter TargetName="Border" Property="Background" Value="#26272B"/>
                                <Setter Property="Foreground" Value="#E8E6E1"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#1F2023"/>
                                <Setter Property="Foreground" Value="#C7C5C0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- TextBox Style -->
        <Style x:Key="InputBox" TargetType="TextBox">
            <Setter Property="Background"      Value="#26272B"/>
            <Setter Property="Foreground"      Value="#E8E6E1"/>
            <Setter Property="CaretBrush"      Value="#C97B3D"/>
            <Setter Property="BorderBrush"     Value="#35363B"/>
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
                                <Setter Property="BorderBrush" Value="#C97B3D"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ComboBox Style -->
        <Style x:Key="StyledCombo" TargetType="ComboBox">
            <Setter Property="Background"      Value="#26272B"/>
            <Setter Property="Foreground"      Value="#E8E6E1"/>
            <Setter Property="BorderBrush"     Value="#35363B"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="10,7"/>
            <Setter Property="FontSize"        Value="12"/>
        </Style>

        <!-- Pill toggle (used by the Create Rule wizard) -->
        <Style x:Key="PillRadio" TargetType="RadioButton">
            <Setter Property="Foreground"  Value="#A3A29E"/>
            <Setter Property="Background"  Value="#1C1D21"/>
            <Setter Property="BorderBrush" Value="#35363B"/>
            <Setter Property="Padding"     Value="12,7"/>
            <Setter Property="Margin"      Value="0,0,6,6"/>
            <Setter Property="FontSize"    Value="12"/>
            <Setter Property="Cursor"      Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="PillBorder" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="PillBorder" Property="BorderBrush" Value="#5A5B60"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="PillBorder" Property="Background"  Value="#3A2A1C"/>
                                <Setter TargetName="PillBorder" Property="BorderBrush" Value="#C97B3D"/>
                                <Setter Property="Foreground" Value="#F0C08A"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SectionHeader" TargetType="TextBlock">
            <Setter Property="FontSize"   Value="9"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Foreground" Value="#8C8B86"/>
            <Setter Property="Margin"     Value="0,16,0,8"/>
        </Style>

        <Style x:Key="FieldLabel" TargetType="TextBlock">
            <Setter Property="FontSize"   Value="11"/>
            <Setter Property="Foreground" Value="#A3A29E"/>
            <Setter Property="Margin"     Value="0,0,0,4"/>
        </Style>

        <Style x:Key="DarkCheck" TargetType="CheckBox">
            <Setter Property="Foreground" Value="#E8E6E1"/>
            <Setter Property="FontSize"   Value="12"/>
            <Setter Property="Margin"     Value="0,0,18,6"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>

        <!-- DataGrid Style -->
        <Style x:Key="ResultGrid" TargetType="DataGrid">
            <Setter Property="Background"            Value="#1F2023"/>
            <Setter Property="Foreground"            Value="#E8E6E1"/>
            <Setter Property="BorderBrush"           Value="#35363B"/>
            <Setter Property="BorderThickness"       Value="1"/>
            <Setter Property="GridLinesVisibility"   Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#35363B"/>
            <Setter Property="RowBackground"         Value="#1F2023"/>
            <Setter Property="AlternatingRowBackground" Value="#232428"/>
            <Setter Property="FontSize"              Value="12"/>
            <Setter Property="AutoGenerateColumns"   Value="True"/>
            <Setter Property="IsReadOnly"            Value="True"/>
            <Setter Property="SelectionMode"         Value="Single"/>
            <Setter Property="HeadersVisibility"     Value="Column"/>
            <Setter Property="CanUserResizeRows"     Value="False"/>
            <Setter Property="ColumnHeaderStyle">
                <Setter.Value>
                    <Style TargetType="DataGridColumnHeader">
                        <Setter Property="Background"  Value="#26272B"/>
                        <Setter Property="Foreground"  Value="#A3A29E"/>
                        <Setter Property="Padding"     Value="10,6"/>
                        <Setter Property="FontSize"    Value="11"/>
                        <Setter Property="FontWeight"  Value="SemiBold"/>
                        <Setter Property="BorderBrush" Value="#35363B"/>
                        <Setter Property="BorderThickness" Value="0,0,0,1"/>
                    </Style>
                </Setter.Value>
            </Setter>
            <Setter Property="CellStyle">
                <Setter.Value>
                    <Style TargetType="DataGridCell">
                        <Setter Property="BorderThickness" Value="0"/>
                        <Setter Property="Padding"         Value="10,5"/>
                        <Setter Property="Foreground"      Value="#E8E6E1"/>
                        <Style.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter Property="Background" Value="#35363B"/>
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
        <Border Grid.Column="0" Background="#1F2023"
                BorderBrush="#35363B" BorderThickness="0,0,1,0">
            <DockPanel>
                <!-- Logo / Title -->
                <StackPanel DockPanel.Dock="Top" Margin="16,24,16,20">
                    <TextBlock Text="⚡ EpmTools" FontSize="18" FontWeight="Bold"
                               Foreground="#E8E6E1"/>
                    <TextBlock Text="Endpoint Privilege Management"
                               FontSize="10" Foreground="#6B6A66" Margin="0,3,0,0"
                               TextWrapping="Wrap"/>
                </StackPanel>

                <!-- Module Status -->
                <Border DockPanel.Dock="Top" Margin="12,0,12,16"
                        Background="#26272B" CornerRadius="8" Padding="12,10">
                    <StackPanel>
                        <TextBlock Text="MODULE STATUS" FontSize="9" FontWeight="Bold"
                                   Foreground="#6B6A66"
                                   Margin="0,0,0,6"/>
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Ellipse x:Name="StatusDot" Width="8" Height="8"
                                     Fill="#C1554A" Margin="0,0,8,0"
                                     VerticalAlignment="Center"/>
                            <TextBlock x:Name="StatusText" Text="Not Loaded"
                                       FontSize="12" Foreground="#A3A29E"
                                       VerticalAlignment="Center"/>
                        </StackPanel>
                    </StackPanel>
                </Border>

                <!-- Navigation -->
                <StackPanel DockPanel.Dock="Top" Margin="8,0">
                    <TextBlock Text="CMDLETS" FontSize="9" FontWeight="Bold"
                               Foreground="#6B6A66" Margin="12,0,0,8"/>

                    <RadioButton x:Name="navHome" Style="{StaticResource NavButton}"
                                 IsChecked="True">Dashboard</RadioButton>

                    <RadioButton x:Name="navPolicies" Style="{StaticResource NavButton}">Get-Policies</RadioButton>

                    <RadioButton x:Name="navElevationRules" Style="{StaticResource NavButton}">Get-ElevationRules</RadioButton>

                    <RadioButton x:Name="navClientSettings" Style="{StaticResource NavButton}">Get-ClientSettings</RadioButton>

                    <RadioButton x:Name="navFileAttributes" Style="{StaticResource NavButton}">Get-FileAttributes</RadioButton>

                    <Separator Background="#35363B" Margin="4,10"/>
                    <TextBlock Text="REPORTS" FontSize="9" FontWeight="Bold"
                               Foreground="#6B6A66" Margin="12,0,0,8"/>
                    <RadioButton x:Name="navReports" Style="{StaticResource NavButton}">Reports</RadioButton>

                    <Separator Background="#35363B" Margin="4,10"/>
                    <TextBlock Text="INTUNE" FontSize="9" FontWeight="Bold"
                               Foreground="#C97B3D" Margin="12,0,0,8"/>
                    <RadioButton x:Name="navCreateRule" Style="{StaticResource NavButton}">Create Rule</RadioButton>
                    <RadioButton x:Name="navRulePolicies" Style="{StaticResource NavButton}">Rule Policies</RadioButton>
                </StackPanel>

                <!-- Load module button at bottom -->
                <StackPanel DockPanel.Dock="Bottom" Margin="12,0,12,16">
                    <Separator Background="#35363B" Margin="0,0,0,12"/>
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
        <Grid Grid.Column="1" Background="#17181C">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*" MinHeight="200"/>
                <RowDefinition Height="6"/>
                <RowDefinition Height="360" MinHeight="110"/>
            </Grid.RowDefinitions>

            <!-- Top Bar -->
            <Border Grid.Row="0" Background="#1F2023"
                    BorderBrush="#35363B" BorderThickness="0,0,0,1"
                    Padding="20,14">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="PageTitle" Text="Dashboard"
                                   FontSize="18" FontWeight="SemiBold"
                                   Foreground="#E8E6E1"/>
                        <TextBlock x:Name="PageSubtitle"
                                   Text="EPM module overview and quick actions"
                                   FontSize="12" Foreground="#A3A29E" Margin="0,2,0,0"/>
                    </StackPanel>
                    <TextBlock Grid.Column="1" x:Name="ClockText"
                               FontSize="11" Foreground="#6B6A66"
                               VerticalAlignment="Center" FontFamily="Consolas"/>
                </Grid>
            </Border>

            <!-- Page Content (Cards / Panels) -->
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                          Background="#17181C">
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
                            <Border Grid.Column="0" Background="#26272B"
                                    CornerRadius="10" Padding="16" Margin="0,0,8,0">
                                <StackPanel>
                                    <TextBlock Text="📋" FontSize="22" Margin="0,0,0,8"/>
                                    <TextBlock Text="EPM Policies" FontSize="13"
                                               FontWeight="SemiBold" Foreground="#E8E6E1"/>
                                    <TextBlock Text="Retrieve ElevationRules or ClientSettings policies from the EPM Agent."
                                               FontSize="11" Foreground="#A3A29E"
                                               TextWrapping="Wrap" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                            <!-- Card 2 -->
                            <Border Grid.Column="1" Background="#26272B"
                                    CornerRadius="10" Padding="16" Margin="4,0,4,0">
                                <StackPanel>
                                    <TextBlock Text="🛡️" FontSize="22" Margin="0,0,0,8"/>
                                    <TextBlock Text="Elevation Rules" FontSize="13"
                                               FontWeight="SemiBold" Foreground="#E8E6E1"/>
                                    <TextBlock Text="Query EPM Agent lookup for rules by FileName or CertificatePayload."
                                               FontSize="11" Foreground="#A3A29E"
                                               TextWrapping="Wrap" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                            <!-- Card 3 -->
                            <Border Grid.Column="2" Background="#26272B"
                                    CornerRadius="10" Padding="16" Margin="8,0,0,0">
                                <StackPanel>
                                    <TextBlock Text="📁" FontSize="22" Margin="0,0,0,8"/>
                                    <TextBlock Text="File Attributes" FontSize="13"
                                               FontWeight="SemiBold" Foreground="#E8E6E1"/>
                                    <TextBlock Text="Extract publisher and CA certificates from .exe files for rule building."
                                               FontSize="11" Foreground="#A3A29E"
                                               TextWrapping="Wrap" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- Getting Started -->
                        <Border Background="#26272B" CornerRadius="10" Padding="20">
                            <StackPanel>
                                <TextBlock Text="Getting Started" FontSize="14"
                                           FontWeight="SemiBold" Foreground="#E8E6E1"
                                           Margin="0,0,0,12"/>
                                <StackPanel Margin="0,0,0,8">
                                    <TextBlock FontSize="12" Foreground="#A3A29E" TextWrapping="Wrap">
                                        <Run Foreground="#C97B3D" FontWeight="SemiBold">1.</Run>
                                        <Run> Click </Run>
                                        <Run Foreground="#E8E6E1" FontWeight="SemiBold">⚡ Load EpmTools Module</Run>
                                        <Run> in the sidebar to import EpmCmdlets.dll from the EPM Agent.</Run>
                                    </TextBlock>
                                </StackPanel>
                                <StackPanel Margin="0,0,0,8">
                                    <TextBlock FontSize="12" Foreground="#A3A29E" TextWrapping="Wrap">
                                        <Run Foreground="#C97B3D" FontWeight="SemiBold">2.</Run>
                                        <Run> Navigate to a cmdlet tab, configure parameters, and click </Run>
                                        <Run Foreground="#E8E6E1" FontWeight="SemiBold">Run</Run>
                                        <Run>.</Run>
                                    </TextBlock>
                                </StackPanel>
                                <StackPanel>
                                    <TextBlock FontSize="12" Foreground="#A3A29E" TextWrapping="Wrap">
                                        <Run Foreground="#C97B3D" FontWeight="SemiBold">3.</Run>
                                        <Run> Results appear in the grid above the output console. Use </Run>
                                        <Run Foreground="#E8E6E1" FontWeight="SemiBold">Export CSV</Run>
                                        <Run> to save data.</Run>
                                    </TextBlock>
                                </StackPanel>

                                <Separator Background="#35363B" Margin="0,16"/>

                                <TextBlock Text="Module path:" FontSize="11"
                                           Foreground="#6B6A66" Margin="0,0,0,4"/>
                                <TextBlock Text="C:\Program Files\Microsoft EPM Agent\EpmTools\EpmCmdlets.dll"
                                           FontSize="11" FontFamily="Consolas"
                                           Foreground="#5FA88A" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>

                    <!-- ── PAGE: Get-Policies ── -->
                    <Border x:Name="panelPolicies" Visibility="Collapsed"
                            Background="#26272B" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Select policy type to retrieve:" FontSize="12"
                                       Foreground="#A3A29E" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                                <RadioButton x:Name="rbElevationRules"
                                             Content="ElevationRules" IsChecked="True"
                                             Foreground="#E8E6E1" FontSize="12"
                                             GroupName="PolicyType" Margin="0,0,20,0"/>
                                <RadioButton x:Name="rbClientSettings"
                                             Content="ClientSettings"
                                             Foreground="#E8E6E1" FontSize="12"
                                             GroupName="PolicyType"/>
                            </StackPanel>
                            <Button x:Name="btnRunGetPolicies"
                                    Style="{StaticResource ActionButton}"
                                    Content="▶  Run Get-Policies"
                                    HorizontalAlignment="Left" Padding="16,9"/>
                        </StackPanel>
                    </Border>

                    <!-- ── PAGE: Get-ElevationRules ── -->
                    <Border x:Name="panelElevationRules" Visibility="Collapsed"
                            Background="#26272B" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Lookup type:" FontSize="12"
                                       Foreground="#A3A29E" Margin="0,0,0,6"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                                <RadioButton x:Name="rbLookupFileName"
                                             Content="FileName" IsChecked="True"
                                             Foreground="#E8E6E1" FontSize="12"
                                             GroupName="LookupType" Margin="0,0,20,0"/>
                                <RadioButton x:Name="rbLookupCert"
                                             Content="CertificatePayload"
                                             Foreground="#E8E6E1" FontSize="12"
                                             GroupName="LookupType"/>
                            </StackPanel>

                            <TextBlock Text="Target value (file name, full path, or certificate payload):"
                                       FontSize="12" Foreground="#A3A29E" Margin="0,0,0,6"/>
                            <TextBox x:Name="txtElevationTarget"
                                     Style="{StaticResource InputBox}"
                                     Height="36" Margin="0,0,0,16"
                                     ToolTip="e.g. notepad.exe or C:\Windows\System32\notepad.exe (file name is extracted automatically)"/>

                            <Button x:Name="btnRunElevationRules"
                                    Style="{StaticResource ActionButton}"
                                    Content="▶  Run Get-ElevationRules"
                                    HorizontalAlignment="Left" Padding="16,9"/>
                        </StackPanel>
                    </Border>

                    <!-- ── PAGE: Get-ClientSettings ── -->
                    <Border x:Name="panelClientSettings" Visibility="Collapsed"
                            Background="#26272B" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Processes all existing client settings policies to display the effective settings used by EPM on this device."
                                       FontSize="12" Foreground="#A3A29E" TextWrapping="Wrap"
                                       Margin="0,0,0,16"/>
                            <Button x:Name="btnRunClientSettings"
                                    Style="{StaticResource ActionButton}"
                                    Content="▶  Run Get-ClientSettings"
                                    HorizontalAlignment="Left" Padding="16,9"/>
                        </StackPanel>
                    </Border>

                    <!-- ── PAGE: Get-FileAttributes ── -->
                    <Border x:Name="panelFileAttributes" Visibility="Collapsed"
                            Background="#26272B" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Select an .exe file to extract its publisher and CA certificates:"
                                       FontSize="12" Foreground="#A3A29E" Margin="0,0,0,8"/>

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
                                         Foreground="#6B6A66"/>
                                <Button x:Name="btnBrowseExe"
                                        Style="{StaticResource SecondaryButton}"
                                        Grid.Column="1" Content="Browse…"
                                        Padding="14,9" Margin="8,0,0,0"/>
                            </Grid>

                            <TextBlock Text="Output folder for extracted certificates:"
                                       FontSize="12" Foreground="#A3A29E" Margin="0,0,0,8"/>
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

                    <!-- ── PAGE: Reports ── -->
                    <Border x:Name="panelReports" Visibility="Collapsed"
                            Background="#26272B" CornerRadius="10" Padding="20">
                        <StackPanel>

                            <!-- Header -->
                            <TextBlock Text="EPM Elevation Events"
                                       FontSize="14" FontWeight="SemiBold"
                                       Foreground="#E8E6E1" Margin="0,0,0,4"/>
                            <TextBlock Text="Retrieve elevation events from Intune Endpoint Privilege Management via Microsoft Graph API."
                                       FontSize="12" Foreground="#A3A29E"
                                       TextWrapping="Wrap" Margin="0,0,0,24"/>

                            <!-- Authentication -->
                            <TextBlock Text="AUTHENTICATION" FontSize="9" FontWeight="Bold"
                                       Foreground="#6B6A66" Margin="0,0,0,8"/>
                            <TextBlock Text="Sign in with your browser. No extra modules required — uses OAuth2 with PKCE. Requires DeviceManagementManagedDevices.Read.All permission."
                                       FontSize="11" Foreground="#A3A29E"
                                       TextWrapping="Wrap" Margin="0,0,0,10"/>
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="txtTenantId" Style="{StaticResource InputBox}"
                                         Grid.Column="0" Height="36"
                                         ToolTip="Tenant ID or domain (e.g. contoso.onmicrosoft.com) — leave blank to use default"/>
                                <Button x:Name="btnConnectGraph" Style="{StaticResource ActionButton}"
                                        Grid.Column="1" Content="Connect to Graph"
                                        Padding="14,9" Margin="8,0,0,0"/>
                            </Grid>
                            <TextBlock x:Name="lblGraphStatus" Text="Not connected."
                                       FontSize="12" Foreground="#6B6A66" Margin="0,0,0,24"/>

                            <!-- Elevation Events report -->
                            <TextBlock Text="ELEVATION EVENTS REPORT" FontSize="9" FontWeight="Bold"
                                       Foreground="#6B6A66" Margin="0,0,0,8"/>
                            <TextBlock FontSize="11" Foreground="#A3A29E" TextWrapping="Wrap" Margin="0,0,0,4">
                                <Run>Endpoint: </Run>
                                <Run FontFamily="Consolas" Foreground="#E0A868">GET /beta/deviceManagement/privilegeManagementElevations</Run>
                            </TextBlock>
                            <TextBlock Text="All pages are fetched automatically. Results populate the grid and raw output pane below."
                                       FontSize="11" Foreground="#A3A29E" TextWrapping="Wrap" Margin="0,0,0,16"/>
                            <Button x:Name="btnLoadElevationReport" Style="{StaticResource ActionButton}"
                                    Content="▶  Load Elevation Events"
                                    HorizontalAlignment="Left" Padding="16,9"
                                    IsEnabled="False"/>

                        </StackPanel>
                    </Border>

                    <!-- ── PAGE: Create Rule (Intune) ── -->
                    <StackPanel x:Name="panelCreateRule" Visibility="Collapsed">

                        <!-- Graph connection bar -->
                        <Border Background="#26272B" CornerRadius="10" Padding="14,10" Margin="0,0,0,12">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <Ellipse x:Name="ruleGraphDot" Width="8" Height="8" Fill="#C1554A"
                                             Margin="0,0,8,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="lblRuleGraphStatus" Text="Microsoft Graph: not connected"
                                               FontSize="12" Foreground="#A3A29E" VerticalAlignment="Center"
                                               TextWrapping="Wrap"/>
                                </StackPanel>
                                <TextBox x:Name="txtRuleTenantId" Grid.Column="1" Style="{StaticResource InputBox}"
                                         Width="240" Height="32" Margin="12,0,0,0"
                                         ToolTip="Tenant ID or domain (e.g. contoso.onmicrosoft.com). Leave blank for your home tenant."/>
                                <Button x:Name="btnRuleConnectGraph" Grid.Column="2" Style="{StaticResource ActionButton}"
                                        Content="Connect to Graph" Padding="14,8" Margin="8,0,0,0"/>
                            </Grid>
                        </Border>

                        <!-- Stepper -->
                        <StackPanel Orientation="Horizontal" Margin="2,0,0,12">
                            <Border x:Name="stepBadge1" Width="22" Height="22" CornerRadius="11" BorderThickness="1">
                                <TextBlock x:Name="stepNum1" Text="1" FontSize="11" FontWeight="Bold"
                                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <TextBlock x:Name="stepText1" Text="Source" Margin="8,0,0,0" VerticalAlignment="Center" FontSize="12"/>
                            <TextBlock Text="——" Foreground="#35363B" Margin="12,0" VerticalAlignment="Center"/>
                            <Border x:Name="stepBadge2" Width="22" Height="22" CornerRadius="11" BorderThickness="1">
                                <TextBlock x:Name="stepNum2" Text="2" FontSize="11" FontWeight="Bold"
                                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <TextBlock x:Name="stepText2" Text="Rule details" Margin="8,0,0,0" VerticalAlignment="Center" FontSize="12"/>
                            <TextBlock Text="——" Foreground="#35363B" Margin="12,0" VerticalAlignment="Center"/>
                            <Border x:Name="stepBadge3" Width="22" Height="22" CornerRadius="11" BorderThickness="1">
                                <TextBlock x:Name="stepNum3" Text="3" FontSize="11" FontWeight="Bold"
                                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <TextBlock x:Name="stepText3" Text="Target policy" Margin="8,0,0,0" VerticalAlignment="Center" FontSize="12"/>
                            <TextBlock Text="——" Foreground="#35363B" Margin="12,0" VerticalAlignment="Center"/>
                            <Border x:Name="stepBadge4" Width="22" Height="22" CornerRadius="11" BorderThickness="1">
                                <TextBlock x:Name="stepNum4" Text="4" FontSize="11" FontWeight="Bold"
                                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <TextBlock x:Name="stepText4" Text="Review &amp; push" Margin="8,0,0,0" VerticalAlignment="Center" FontSize="12"/>
                        </StackPanel>

                        <!-- STEP 1: Source -->
                        <Border x:Name="ruleStep1" Background="#26272B" CornerRadius="10" Padding="20">
                            <StackPanel>
                                <TextBlock Text="START A RULE FROM…" Style="{StaticResource SectionHeader}" Margin="0,0,0,8"/>
                                <UniformGrid Columns="4" Margin="0,0,0,4">
                                    <Button x:Name="btnSrcExe" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0" Padding="12,10"
                                            HorizontalContentAlignment="Left">
                                        <StackPanel>
                                            <TextBlock Text="Executable file" FontWeight="SemiBold" FontSize="13"/>
                                            <TextBlock Text="Hash, version info and signing certs" FontSize="11"
                                                       Foreground="#C7C5C0" FontWeight="Normal" TextWrapping="Wrap" Margin="0,3,0,0"/>
                                        </StackPanel>
                                    </Button>
                                    <Button x:Name="btnSrcEvent" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0" Padding="12,10">
                                        <StackPanel>
                                            <TextBlock Text="Elevation event" FontWeight="SemiBold" FontSize="13"/>
                                            <TextBlock Text="Pick an event from the EPM report" FontSize="11"
                                                       Foreground="#C7C5C0" FontWeight="Normal" TextWrapping="Wrap" Margin="0,3,0,0"/>
                                        </StackPanel>
                                    </Button>
                                    <Button x:Name="btnSrcDraft" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0" Padding="12,10">
                                        <StackPanel>
                                            <TextBlock Text="Saved draft" FontWeight="SemiBold" FontSize="13"/>
                                            <TextBlock Text="Open a rule draft (.json)" FontSize="11"
                                                       Foreground="#C7C5C0" FontWeight="Normal" TextWrapping="Wrap" Margin="0,3,0,0"/>
                                        </StackPanel>
                                    </Button>
                                    <Button x:Name="btnSrcBlank" Style="{StaticResource SecondaryButton}" Padding="12,10">
                                        <StackPanel>
                                            <TextBlock Text="Blank rule" FontWeight="SemiBold" FontSize="13"/>
                                            <TextBlock Text="Fill in everything yourself" FontSize="11"
                                                       Foreground="#C7C5C0" FontWeight="Normal" TextWrapping="Wrap" Margin="0,3,0,0"/>
                                        </StackPanel>
                                    </Button>
                                </UniformGrid>
                                <TextBlock x:Name="lblSourceInfo" Text="No source selected yet."
                                           FontSize="12" Foreground="#A3A29E" Margin="0,12,0,0" TextWrapping="Wrap"
                                           FontFamily="Consolas"/>
                                <TextBlock x:Name="lblAttrHeader" Text="DETECTED ATTRIBUTES — CHOOSE WHAT THE RULE MATCHES ON"
                                           Style="{StaticResource SectionHeader}" Visibility="Collapsed"/>
                                <StackPanel x:Name="attrList"/>
                            </StackPanel>
                        </Border>

                        <!-- STEP 2: Rule details -->
                        <Grid x:Name="ruleStep2" Visibility="Collapsed">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="300"/>
                            </Grid.ColumnDefinitions>

                            <Border Grid.Column="0" Background="#26272B" CornerRadius="10" Padding="20,8,20,20" Margin="0,0,12,0">
                                <StackPanel>
                                    <TextBlock Text="RULE" Style="{StaticResource SectionHeader}"/>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="10"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="Rule name *" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtRuleName" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                        <StackPanel Grid.Column="2">
                                            <TextBlock Text="Description" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtRuleDesc" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                    </Grid>

                                    <TextBlock Text="FILE MATCH" Style="{StaticResource SectionHeader}"/>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="10"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                        </Grid.RowDefinitions>
                                        <StackPanel Grid.Row="0" Grid.Column="0" Margin="0,0,0,10">
                                            <TextBlock Text="File name *" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtFileName" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                        <StackPanel Grid.Row="0" Grid.Column="2" Margin="0,0,0,10">
                                            <TextBlock Text="File path (folder)" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtFilePath" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                        <StackPanel Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="3" Margin="0,0,0,10">
                                            <TextBlock Text="File hash (SHA-256)" Style="{StaticResource FieldLabel}"/>
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="Auto"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBox x:Name="txtFileHash" Style="{StaticResource InputBox}" Height="34" FontSize="11"/>
                                                <Button x:Name="btnHashFromFile" Grid.Column="1" Style="{StaticResource SecondaryButton}"
                                                        Content="Hash a file…" Padding="12,8" Margin="8,0,0,0"/>
                                            </Grid>
                                        </StackPanel>
                                        <StackPanel Grid.Row="2" Grid.Column="0" Margin="0,0,0,10">
                                            <TextBlock Text="Minimum version" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtMinVersion" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                        <StackPanel Grid.Row="2" Grid.Column="2" Margin="0,0,0,10">
                                            <TextBlock Text="Product name" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtProductName" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                        <StackPanel Grid.Row="3" Grid.Column="0">
                                            <TextBlock Text="Internal name" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtInternalName" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                        <StackPanel Grid.Row="3" Grid.Column="2">
                                            <TextBlock Text="File description" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtFileDescription" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                    </Grid>

                                    <TextBlock Text="SIGNATURE" Style="{StaticResource SectionHeader}"/>
                                    <WrapPanel>
                                        <RadioButton x:Name="rbSigNone" GroupName="SigSource" Style="{StaticResource PillRadio}" Content="Not configured" IsChecked="True"/>
                                        <RadioButton x:Name="rbSigUpload" GroupName="SigSource" Style="{StaticResource PillRadio}" Content="Upload certificate"/>
                                        <RadioButton x:Name="rbSigReusable" GroupName="SigSource" Style="{StaticResource PillRadio}" Content="Reusable certificate"/>
                                    </WrapPanel>
                                    <StackPanel x:Name="panelSigUpload" Visibility="Collapsed" Margin="0,4,0,0">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBox x:Name="txtCertFile" Style="{StaticResource InputBox}" Height="34" IsReadOnly="True"
                                                     Text="(certificate taken from source)"/>
                                            <Button x:Name="btnBrowseCert" Grid.Column="1" Style="{StaticResource SecondaryButton}"
                                                    Content="Browse .cer…" Padding="12,8" Margin="8,0,0,0"/>
                                        </Grid>
                                        <TextBlock x:Name="lblCertInfo" Text="No certificate loaded." FontSize="11" Foreground="#A3A29E"
                                                   FontFamily="Consolas" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <StackPanel x:Name="panelSigReusable" Visibility="Collapsed" Margin="0,4,0,0">
                                        <Button x:Name="btnLoadReusable" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Left"
                                                Content="Load reusable certificates from Intune" Padding="12,7" Margin="0,0,0,6"/>
                                        <DataGrid x:Name="gridReusable" Style="{StaticResource ResultGrid}" Height="110"/>
                                    </StackPanel>
                                    <StackPanel x:Name="panelCertType" Visibility="Collapsed" Margin="0,8,0,0">
                                        <TextBlock Text="Certificate type" Style="{StaticResource FieldLabel}"/>
                                        <WrapPanel>
                                            <RadioButton x:Name="rbCertPublisher" GroupName="CertType" Style="{StaticResource PillRadio}" Content="Publisher" IsChecked="True"/>
                                            <RadioButton x:Name="rbCertCA" GroupName="CertType" Style="{StaticResource PillRadio}" Content="Certificate authority"/>
                                        </WrapPanel>
                                    </StackPanel>

                                    <TextBlock Text="ELEVATION TYPE" Style="{StaticResource SectionHeader}"/>
                                    <WrapPanel>
                                        <RadioButton x:Name="rbElAuto" GroupName="ElType" Style="{StaticResource PillRadio}" Content="Automatic"/>
                                        <RadioButton x:Name="rbElUser" GroupName="ElType" Style="{StaticResource PillRadio}" Content="User confirmed" IsChecked="True"/>
                                        <RadioButton x:Name="rbElSupport" GroupName="ElType" Style="{StaticResource PillRadio}" Content="Support approved"/>
                                        <RadioButton x:Name="rbElCurrent" GroupName="ElType" Style="{StaticResource PillRadio}" Content="Elevate as current user"/>
                                        <RadioButton x:Name="rbElDeny" GroupName="ElType" Style="{StaticResource PillRadio}" Content="Deny"/>
                                    </WrapPanel>
                                    <TextBlock x:Name="lblElHelp" FontSize="11" Foreground="#A3A29E" TextWrapping="Wrap" Margin="0,2,0,6"/>
                                    <WrapPanel x:Name="panelValidation">
                                        <CheckBox x:Name="chkValJustification" Style="{StaticResource DarkCheck}" Content="Business justification" IsChecked="True"/>
                                        <CheckBox x:Name="chkValWinAuth" Style="{StaticResource DarkCheck}" Content="Windows authentication"/>
                                    </WrapPanel>

                                    <StackPanel x:Name="panelChildProc">
                                        <TextBlock Text="CHILD PROCESSES" Style="{StaticResource SectionHeader}"/>
                                        <WrapPanel>
                                            <RadioButton x:Name="rbChildRule" GroupName="ChildProc" Style="{StaticResource PillRadio}" Content="Require rule to elevate" IsChecked="True"/>
                                            <RadioButton x:Name="rbChildDeny" GroupName="ChildProc" Style="{StaticResource PillRadio}" Content="Deny all"/>
                                            <RadioButton x:Name="rbChildAllow" GroupName="ChildProc" Style="{StaticResource PillRadio}" Content="Allow all child processes to run elevated"/>
                                        </WrapPanel>
                                    </StackPanel>
                                </StackPanel>
                            </Border>

                            <StackPanel Grid.Column="1">
                                <Border Background="#26272B" CornerRadius="10" Padding="16" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="RULE STRENGTH" Style="{StaticResource SectionHeader}" Margin="0,0,0,10"/>
                                        <UniformGrid Columns="4" Height="6" Margin="0,0,0,8">
                                            <Border x:Name="strBar1" CornerRadius="3" Margin="0,0,3,0" Background="#3A3B40"/>
                                            <Border x:Name="strBar2" CornerRadius="3" Margin="0,0,3,0" Background="#3A3B40"/>
                                            <Border x:Name="strBar3" CornerRadius="3" Margin="0,0,3,0" Background="#3A3B40"/>
                                            <Border x:Name="strBar4" CornerRadius="3" Background="#3A3B40"/>
                                        </UniformGrid>
                                        <TextBlock x:Name="lblStrength" Text="—" FontSize="13" FontWeight="SemiBold" Foreground="#E8E6E1"/>
                                        <TextBlock x:Name="lblStrengthTips" FontSize="11" Foreground="#A3A29E" TextWrapping="Wrap" Margin="0,8,0,0"/>
                                        <TextBlock x:Name="lblRuleIssues" FontSize="11" Foreground="#E0A868" TextWrapping="Wrap" Margin="0,8,0,0"/>
                                    </StackPanel>
                                </Border>
                                <Border Background="#26272B" CornerRadius="10" Padding="16">
                                    <StackPanel>
                                        <TextBlock Text="SETTINGS PAYLOAD (PREVIEW)" Style="{StaticResource SectionHeader}" Margin="0,0,0,8"/>
                                        <TextBox x:Name="txtRulePreview" Height="360" IsReadOnly="True"
                                                 Background="#131315" Foreground="#E8E6E1" BorderThickness="0"
                                                 FontFamily="Consolas" FontSize="10" Padding="8"
                                                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </Grid>

                        <!-- STEP 3: Target policy -->
                        <Border x:Name="ruleStep3" Visibility="Collapsed" Background="#26272B" CornerRadius="10" Padding="20,8,20,20">
                            <StackPanel>
                                <TextBlock Text="TARGET POLICY" Style="{StaticResource SectionHeader}"/>
                                <WrapPanel>
                                    <RadioButton x:Name="rbTargetExisting" GroupName="Target" Style="{StaticResource PillRadio}" Content="Add to existing policy" IsChecked="True"/>
                                    <RadioButton x:Name="rbTargetNew" GroupName="Target" Style="{StaticResource PillRadio}" Content="Create new policy"/>
                                </WrapPanel>

                                <StackPanel x:Name="panelTargetExisting" Margin="0,6,0,0">
                                    <Grid Margin="0,0,0,8">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBox x:Name="txtPolicyFilter" Style="{StaticResource InputBox}" Height="32"
                                                 ToolTip="Type to filter elevation rules policies"/>
                                        <Button x:Name="btnRefreshPolicies" Grid.Column="1" Style="{StaticResource SecondaryButton}"
                                                Content="Refresh" Padding="14,7" Margin="8,0,0,0"/>
                                    </Grid>
                                    <DataGrid x:Name="gridPolicies" Style="{StaticResource ResultGrid}" Height="190"/>
                                    <TextBlock x:Name="lblPolicyInfo" Text="Select a policy." FontSize="12" Foreground="#A3A29E"
                                               Margin="0,8,0,0" TextWrapping="Wrap"/>
                                    <Border x:Name="panelDuplicate" Visibility="Collapsed" Background="#2A2620" BorderBrush="#4A3A2A"
                                            BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,10,0,0">
                                        <StackPanel>
                                            <TextBlock x:Name="lblDuplicate" FontSize="12" Foreground="#E0A868" TextWrapping="Wrap" Margin="0,0,0,8"/>
                                            <WrapPanel>
                                                <RadioButton x:Name="rbDupAdd" GroupName="Dup" Style="{StaticResource PillRadio}" Content="Add alongside" IsChecked="True"/>
                                                <RadioButton x:Name="rbDupReplace" GroupName="Dup" Style="{StaticResource PillRadio}" Content="Replace existing rule(s) for this file"/>
                                            </WrapPanel>
                                        </StackPanel>
                                    </Border>
                                </StackPanel>

                                <StackPanel x:Name="panelTargetNew" Visibility="Collapsed" Margin="0,6,0,0">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="10"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="Policy name *" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtNewPolicyName" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                        <StackPanel Grid.Column="2">
                                            <TextBlock Text="Description" Style="{StaticResource FieldLabel}"/>
                                            <TextBox x:Name="txtNewPolicyDesc" Style="{StaticResource InputBox}" Height="34"/>
                                        </StackPanel>
                                    </Grid>
                                    <TextBlock Text="ASSIGNMENT" Style="{StaticResource SectionHeader}"/>
                                    <WrapPanel>
                                        <RadioButton x:Name="rbAssignNone" GroupName="Assign" Style="{StaticResource PillRadio}" Content="Don't assign yet" IsChecked="True"/>
                                        <RadioButton x:Name="rbAssignUsers" GroupName="Assign" Style="{StaticResource PillRadio}" Content="All users"/>
                                        <RadioButton x:Name="rbAssignDevices" GroupName="Assign" Style="{StaticResource PillRadio}" Content="All devices"/>
                                        <RadioButton x:Name="rbAssignGroup" GroupName="Assign" Style="{StaticResource PillRadio}" Content="Group…"/>
                                    </WrapPanel>
                                    <StackPanel x:Name="panelGroupSearch" Visibility="Collapsed">
                                        <Grid Margin="0,0,0,8">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBox x:Name="txtGroupSearch" Style="{StaticResource InputBox}" Height="32"
                                                     ToolTip="Group name starts with…"/>
                                            <Button x:Name="btnGroupSearch" Grid.Column="1" Style="{StaticResource SecondaryButton}"
                                                    Content="Search groups" Padding="14,7" Margin="8,0,0,0"/>
                                        </Grid>
                                        <DataGrid x:Name="gridGroups" Style="{StaticResource ResultGrid}" Height="130"/>
                                    </StackPanel>
                                </StackPanel>
                            </StackPanel>
                        </Border>

                        <!-- STEP 4: Review & push -->
                        <Grid x:Name="ruleStep4" Visibility="Collapsed">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="360"/>
                            </Grid.ColumnDefinitions>
                            <Border Grid.Column="0" Background="#26272B" CornerRadius="10" Padding="20,8,20,20" Margin="0,0,12,0">
                                <StackPanel>
                                    <TextBlock Text="SUMMARY" Style="{StaticResource SectionHeader}"/>
                                    <TextBlock x:Name="txtSummary" FontSize="12" Foreground="#E8E6E1" TextWrapping="Wrap"
                                               FontFamily="Consolas" LineHeight="20"/>
                                    <TextBlock Text="GRAPH CALLS" Style="{StaticResource SectionHeader}"/>
                                    <TextBlock x:Name="txtGraphCalls" FontSize="11" Foreground="#E0A868" TextWrapping="Wrap"
                                               FontFamily="Consolas" LineHeight="19"/>
                                    <TextBlock x:Name="lblScopeStatus" FontSize="11" Foreground="#A3A29E" TextWrapping="Wrap" Margin="0,10,0,0"/>
                                </StackPanel>
                            </Border>
                            <Border Grid.Column="1" Background="#26272B" CornerRadius="10" Padding="20,8,20,20">
                                <StackPanel>
                                    <TextBlock Text="PUSH" Style="{StaticResource SectionHeader}"/>
                                    <CheckBox x:Name="chkBackup" Style="{StaticResource DarkCheck}" IsChecked="True"
                                              Content="Save a JSON backup of the policy first"/>
                                    <TextBlock Text="Backups go to Documents\EpmTools\Backups" FontSize="11" Foreground="#8C8B86" Margin="22,0,0,14"/>
                                    <Button x:Name="btnPushRule" Style="{StaticResource ActionButton}" Content="Push rule to Intune"
                                            Padding="14,11" FontSize="13" Margin="0,0,0,8"/>
                                    <Button x:Name="btnDryRun" Style="{StaticResource SecondaryButton}" Content="Dry run (show request, change nothing)"
                                            Padding="14,9"/>
                                    <Border x:Name="panelPushResult" Visibility="Collapsed" CornerRadius="8" Padding="12,10" Margin="0,14,0,0"
                                            BorderThickness="1">
                                        <TextBlock x:Name="lblPushResult" FontSize="12" TextWrapping="Wrap"/>
                                    </Border>
                                    <Button x:Name="btnNewRule" Style="{StaticResource SecondaryButton}" Content="Start another rule"
                                            Padding="14,8" Margin="0,10,0,0" Visibility="Collapsed"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- Wizard footer -->
                        <Grid Margin="0,12,0,0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Button x:Name="btnRuleBack" Style="{StaticResource SecondaryButton}" Content="← Back" Padding="16,9"/>
                            <Button x:Name="btnRuleSaveDraft" Grid.Column="2" Style="{StaticResource SecondaryButton}"
                                    Content="Save draft (JSON)" Padding="14,9" Margin="0,0,8,0"/>
                            <Button x:Name="btnRuleNext" Grid.Column="3" Style="{StaticResource ActionButton}"
                                    Content="Next →" Padding="18,9"/>
                        </Grid>
                    </StackPanel>

                    <!-- ── PAGE: Rule Policies (Intune) ── -->
                    <Border x:Name="panelRulePolicies" Visibility="Collapsed"
                            Background="#26272B" CornerRadius="10" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Elevation rules policies in Intune" FontSize="14" FontWeight="SemiBold"
                                       Foreground="#E8E6E1" Margin="0,0,0,4"/>
                            <TextBlock Text="Lists your EPM elevation rules policies. Select one to show its rules in the Results Grid or export it as JSON. Connect to Graph on the Create Rule page first."
                                       FontSize="12" Foreground="#A3A29E" TextWrapping="Wrap" Margin="0,0,0,14"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                                <Button x:Name="btnLoadRulePolicies" Style="{StaticResource ActionButton}" Content="▶  Load policies" Padding="16,9"/>
                                <Button x:Name="btnShowPolicyRules" Style="{StaticResource SecondaryButton}" Content="Show rules" Padding="14,9" Margin="8,0,0,0"/>
                                <Button x:Name="btnExportPolicyJson" Style="{StaticResource SecondaryButton}" Content="Export policy JSON" Padding="14,9" Margin="8,0,0,0"/>
                            </StackPanel>
                            <DataGrid x:Name="gridRulePolicies" Style="{StaticResource ResultGrid}" Height="220"/>
                        </StackPanel>
                    </Border>

                </Grid>
            </ScrollViewer>

            <!-- Drag to resize page vs. output pane -->
            <GridSplitter Grid.Row="2" Height="6" HorizontalAlignment="Stretch"
                          ResizeDirection="Rows" ResizeBehavior="PreviousAndNext"
                          Background="#1F2023" Cursor="SizeNS"
                          ToolTip="Drag to resize"/>

            <!-- ── OUTPUT / RESULTS PANE ── -->
            <Grid Grid.Row="3" Background="#17181C">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <!-- Results Toolbar -->
                <Border Grid.Row="0" Background="#1F2023"
                        BorderBrush="#35363B" BorderThickness="0,1,0,0"
                        Padding="16,8">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock x:Name="ResultLabel" Text="Output Console"
                                   FontSize="11" FontWeight="SemiBold"
                                   Foreground="#A3A29E" VerticalAlignment="Center"/>
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
                <TabControl Grid.Row="1" Background="#17181C"
                            BorderBrush="#35363B" BorderThickness="0">
                    <TabControl.Resources>
                        <Style TargetType="TabItem">
                            <Setter Property="Background"  Value="#1F2023"/>
                            <Setter Property="Foreground"  Value="#A3A29E"/>
                            <Setter Property="Padding"     Value="12,6"/>
                            <Setter Property="FontSize"    Value="11"/>
                            <Setter Property="BorderThickness" Value="0"/>
                            <Setter Property="Template">
                                <Setter.Value>
                                    <ControlTemplate TargetType="TabItem">
                                        <Border x:Name="TabBorder"
                                                Background="{TemplateBinding Background}"
                                                BorderBrush="{TemplateBinding BorderBrush}"
                                                BorderThickness="{TemplateBinding BorderThickness}"
                                                Padding="{TemplateBinding Padding}">
                                            <ContentPresenter x:Name="ContentSite"
                                                              ContentSource="Header"
                                                              HorizontalAlignment="Center"
                                                              VerticalAlignment="Center"
                                                              TextElement.Foreground="{TemplateBinding Foreground}"/>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="TabBorder" Property="Background" Value="#2A2B30"/>
                                            </Trigger>
                                            <Trigger Property="IsSelected" Value="True">
                                                <Setter TargetName="TabBorder" Property="Background" Value="#26272B"/>
                                                <Setter Property="Foreground" Value="#E8E6E1"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </Setter.Value>
                            </Setter>
                        </Style>
                    </TabControl.Resources>

                    <TabItem Header="📝  Console Log" IsSelected="True">
                        <RichTextBox x:Name="ConsoleLog"
                                 Background="#121214"
                                 Foreground="#5FA88A"
                                 FontFamily="Consolas"
                                 FontSize="14"
                                 IsReadOnly="True"
                                 VerticalScrollBarVisibility="Auto"
                                 HorizontalScrollBarVisibility="Auto"
                                 BorderThickness="0"
                                 Padding="12"/>
                    </TabItem>

                    <TabItem Header="🗒️  Raw Output">
                        <TextBox x:Name="RawOutput"
                                 Background="#131315"
                                 Foreground="#E8E6E1"
                                 FontFamily="Consolas"
                                 FontSize="14"
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

$script:ModuleLoaded  = $false
$script:LastResults   = $null

# Graph auth state (used by Reports panel — no external module required)
$script:GraphToken    = $null
$script:GraphRefresh  = $null
$script:GraphExpiry   = [DateTime]::MinValue
$script:GraphTenant   = 'common'
$script:GraphClient   = '14d82eec-204b-4c2f-b7e8-296a70dab67e'   # Microsoft Graph Command Line Tools (public client)
$script:GraphScope    = 'DeviceManagementManagedDevices.Read.All offline_access'
# Create Rule needs write access to Settings Catalog policies (+ group lookup for assignments)
$script:GraphScopeRules = 'DeviceManagementManagedDevices.Read.All DeviceManagementConfiguration.ReadWrite.All Group.Read.All offline_access'
$script:GraphScopeActive = $script:GraphScope     # scope used for the current token (needed for refresh)
$script:GraphAccount  = $null

# Create Rule / Intune state
$script:Sync               = [hashtable]::Synchronized(@{ PendingEventId = $null })  # filled by the report window
$script:ElevationEvents    = @()      # flattened events (report rows)
$script:ElevationEventsRaw = @{}      # id -> raw Graph elevation event
$script:EpmPolicies        = @()      # cached elevation rules policies
$script:EpmSchemaCache     = @{}      # templateId -> resolved setting definitions
$script:EpmRulesTemplate   = $null
$script:RuleStep           = 1
$script:RuleSuspend        = $false   # stops live preview while the form is filled from code
$script:RuleAttrs          = @()      # attributes detected from the chosen source
$script:RuleCerts          = @{}      # 'publisher' / 'ca' -> X509Certificate2 (or $null)
$script:RuleCertBase64     = $null    # certificate payload for "Upload certificate"
$script:RuleExePath        = $null
$script:SelectedPolicyFull = $null
$script:GraphRedirect = 'http://localhost:18880/'
$script:AuthPs        = $null
$script:AuthHandle    = $null
$script:AuthTimer     = $null

# -------------------------------------------------------------
# Helper functions stored as $script: scriptblock variables.
# This is the ONLY reliable way to call shared logic from
# inside WPF event-handler scriptblocks in Windows PowerShell.
# -------------------------------------------------------------

$script:AppendConsoleText = {
    param([string]$Text, [string]$Color = '#5FA88A', [bool]$Bold = $false, [string]$BgColor = $null)
    $ctrl = $window.FindName('ConsoleLog')
    if (-not $ctrl) { return }
    $ctrl.Dispatcher.Invoke([Action]{
        $bc   = [System.Windows.Media.BrushConverter]::new()
        $para = New-Object System.Windows.Documents.Paragraph
        $para.Margin = New-Object System.Windows.Thickness(0,0,0,1)
        $lines = $Text -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $run = New-Object System.Windows.Documents.Run($lines[$i])
            $run.Foreground = $bc.ConvertFromString($Color)
            if ($Bold)    { $run.FontWeight = [System.Windows.FontWeights]::Bold }
            if ($BgColor) { $run.Background = $bc.ConvertFromString($BgColor) }
            $para.Inlines.Add($run)
            if ($i -lt $lines.Count - 1) { $para.Inlines.Add((New-Object System.Windows.Documents.LineBreak)) }
        }
        $ctrl.Document.Blocks.Add($para)
        $ctrl.ScrollToEnd()
    })
}

$script:WriteLog = {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        "OK"    { "[OK]  " }
        "ERR"   { "[ERR] " }
        "WARN"  { "[WARN]" }
        "CERT"  { "[CERT]" }
        default { "[INFO]" }
    }
    $color = switch ($Level) {
        "OK"    { "#5FA88A" }
        "ERR"   { "#C1554A" }
        "WARN"  { "#D9A441" }
        "CERT"  { "#FFD65C" }
        default { "#5FA88A" }
    }
    $bgColor = if ($Level -eq 'CERT') { "#4A3B12" } else { $null }
    $line = "[$ts] $prefix $Message"
    & $script:AppendConsoleText $line $color ($Level -eq 'CERT') $bgColor
}

$script:SetModuleStatus = {
    param([bool]$Loaded)
    if ($Loaded) {
        $ok = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#5FA88A')
        $window.FindName('StatusDot').Fill        = $ok
        $window.FindName('StatusText').Text       = "Loaded"
        $window.FindName('StatusText').Foreground = $ok
    } else {
        $bad = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#C1554A')
        $window.FindName('StatusDot').Fill        = $bad
        $window.FindName('StatusText').Text       = "Not Loaded"
        $window.FindName('StatusText').Foreground = $bad
    }
}

$script:ShowPanel = {
    param([string]$Name)
    $panels = @(
        'panelHome','panelPolicies','panelElevationRules',
        'panelClientSettings','panelFileAttributes','panelReports',
        'panelCreateRule','panelRulePolicies'
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
    'navElevationRules'   = @{ Panel = 'panelElevationRules';   Title = 'Get-ElevationRules';                Sub = 'Query elevation rules by FileName or CertificatePayload' }
    'navClientSettings'   = @{ Panel = 'panelClientSettings';   Title = 'Get-ClientSettings';                Sub = 'Display effective client settings used by EPM' }
    'navFileAttributes'   = @{ Panel = 'panelFileAttributes';   Title = 'Get-FileAttributes';                Sub = 'Extract publisher and CA certs from an .exe for rule building' }
    'navReports'          = @{ Panel = 'panelReports';          Title = 'Reports';                           Sub = 'Generate and export EPM reports' }
    'navCreateRule'       = @{ Panel = 'panelCreateRule';       Title = 'Create EPM Rule';                   Sub = 'Build an elevation rule and push it to an Intune EPM policy via Microsoft Graph' }
    'navRulePolicies'     = @{ Panel = 'panelRulePolicies';     Title = 'Rule Policies';                     Sub = 'Browse and export Intune elevation rules policies' }
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
    $window.FindName('ConsoleLog').Document.Blocks.Clear()
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
    if ($lookup -eq 'FileName') {
        $target = Split-Path -Path $target -Leaf
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
        & $script:AppendConsoleText $pretty '#E8E6E1'
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
        $window.FindName('txtExePath').Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E8E6E1')
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
        $publisherCerts = @()
        $pendingPublisherCert = $null
        foreach ($obj in $allOutput) {
            if ($obj -is [System.Management.Automation.VerboseRecord]) {
                $msg = $obj.Message
                if ($msg -match 'Publisher Cert\?\s*\[True\]') {
                    $pendingPublisherCert = if ($msg -match 'Name:\s*\[(?<n>[^\]]+)\]') { $Matches['n'] } else { 'Unknown' }
                    & $script:WriteLog "PUBLISHER CERTIFICATE FOUND: $pendingPublisherCert" "CERT"
                } elseif ($pendingPublisherCert -and $msg -match 'Certificate exported to:\s*(?<path>.+)$') {
                    $publisherCerts += [PSCustomObject]@{ Name = $pendingPublisherCert; Path = $Matches['path'] }
                    & $script:WriteLog "PUBLISHER CERTIFICATE EXPORTED: $pendingPublisherCert -> $($Matches['path'])" "CERT"
                    $pendingPublisherCert = $null
                } else {
                    & $script:WriteLog "VERBOSE: $msg" "INFO"
                }
            } else {
                $data += $obj
            }
        }

        if ($data.Count -eq 0 -and $publisherCerts.Count -eq 0) {
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

                if ($publisherCerts.Count -gt 0) {
                    $sepRow = $dt.NewRow()
                    $sepRow['Property'] = "-- Publisher Certificate(s) --"
                    $sepRow['Value']    = ''
                    $dt.Rows.Add($sepRow)
                    foreach ($cert in $publisherCerts) {
                        $nameRow = $dt.NewRow()
                        $nameRow['Property'] = 'Publisher Certificate Name'
                        $nameRow['Value']    = $cert.Name
                        $dt.Rows.Add($nameRow)
                        $pathRow = $dt.NewRow()
                        $pathRow['Property'] = 'Publisher Certificate Path'
                        $pathRow['Value']    = $cert.Path
                        $dt.Rows.Add($pathRow)
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
# Reports — Microsoft Graph / EPM Elevation Events
# (No external module required — pure OAuth2 PKCE via browser)
# -------------------------------------------------------------
# Shared status display for the Reports page and the Create Rule page
$script:SetGraphStatus = {
    param([string]$Text, [string]$Color)
    $b = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
    $l1 = $window.FindName('lblGraphStatus');     if ($l1) { $l1.Text = $Text; $l1.Foreground = $b }
    $l2 = $window.FindName('lblRuleGraphStatus'); if ($l2) { $l2.Text = "Microsoft Graph: $Text"; $l2.Foreground = $b }
    $d  = $window.FindName('ruleGraphDot');       if ($d)  { $d.Fill = $b }
}

$script:SetConnectButtons = {
    param([bool]$Enabled)
    foreach ($n in 'btnConnectGraph','btnRuleConnectGraph') { $b = $window.FindName($n); if ($b) { $b.IsEnabled = $Enabled } }
}

# Returns the delegated scopes in the current access token
$script:GetTokenScopes = {
    if (-not $script:GraphToken) { return @() }
    try {
        $p  = $script:GraphToken.Split('.')[1]
        $p += '=' * ((4 - $p.Length % 4) % 4)
        $c  = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.Replace('-','+').Replace('_','/'))) | ConvertFrom-Json
        return @("$($c.scp)" -split ' ' | Where-Object { $_ })
    } catch { return @() }
}

$script:StartGraphSignIn = {
    param([string]$TenantInput, [string]$Scope)
    $script:GraphTenant      = if ($TenantInput) { $TenantInput } else { 'common' }
    $script:GraphScopeActive = $Scope

    # Clean up any previous in-flight auth
    if ($script:AuthTimer) { $script:AuthTimer.Stop(); $script:AuthTimer = $null }
    if ($script:AuthPs)    { try { $script:AuthPs.Stop() } catch {} }

    # PKCE: generate code_verifier and code_challenge
    $raw       = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($raw)
    $verifier  = [Convert]::ToBase64String($raw).TrimEnd('=').Replace('+','-').Replace('/','_')
    $sha256    = [System.Security.Cryptography.SHA256]::Create()
    $challenge = [Convert]::ToBase64String(
                     $sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($verifier))
                 ).TrimEnd('=').Replace('+','-').Replace('/','_')

    # Build authorization URL
    $eRedir  = [System.Uri]::EscapeDataString($script:GraphRedirect)
    $eScope  = [System.Uri]::EscapeDataString($Scope)
    $authUrl = "https://login.microsoftonline.com/$($script:GraphTenant)/oauth2/v2.0/authorize" +
               "?client_id=$($script:GraphClient)&response_type=code" +
               "&redirect_uri=$eRedir&scope=$eScope" +
               "&code_challenge=$challenge&code_challenge_method=S256"

    # Background runspace: start local HTTP listener, wait for redirect, exchange code for token
    $authScript = {
        param($clientId, $tenantId, $scope, $redirectUri, $verifier)
        $r = @{ Success = $false; Token = $null; Refresh = $null; ExpiresIn = 3600; Account = 'Unknown'; Error = $null }
        try {
            $listener = [System.Net.HttpListener]::new()
            $listener.Prefixes.Add($redirectUri)
            $listener.Start()
            $ctx = $listener.GetContext()   # blocks until browser redirects here

            # Parse query string
            $qs = @{}
            foreach ($pair in ($ctx.Request.Url.Query.TrimStart('?') -split '&')) {
                $kv = $pair -split '=', 2
                if ($kv.Count -eq 2) { $qs[$kv[0]] = [System.Uri]::UnescapeDataString($kv[1].Replace('+',' ')) }
            }

            # Send a friendly page back to the browser
            $html = '<html><meta charset="utf-8"><body style="font-family:Segoe UI;background:#17181C;color:#E8E6E1;padding:60px 80px"><h2>&#10003; Signed in</h2><p style="color:#A3A29E">Authentication complete. You can close this tab and return to EpmTools.</p></body></html>'
            $buf  = [System.Text.Encoding]::UTF8.GetBytes($html)
            $ctx.Response.ContentType     = 'text/html; charset=utf-8'
            $ctx.Response.ContentLength64 = $buf.Length
            $ctx.Response.OutputStream.Write($buf, 0, $buf.Length)
            $ctx.Response.Close()
            $listener.Stop()

            if ($qs['error'])  { $r.Error = "$($qs['error']): $($qs['error_description'])"; return $r }
            $code = $qs['code']
            if (-not $code)    { $r.Error = 'No authorization code returned.'; return $r }

            # Exchange authorization code for access token
            $body = "client_id=$([System.Uri]::EscapeDataString($clientId))" +
                    "&code=$([System.Uri]::EscapeDataString($code))" +
                    "&redirect_uri=$([System.Uri]::EscapeDataString($redirectUri))" +
                    "&grant_type=authorization_code" +
                    "&code_verifier=$([System.Uri]::EscapeDataString($verifier))" +
                    "&scope=$([System.Uri]::EscapeDataString($scope))"
            $tok  = Invoke-RestMethod -Method POST -ErrorAction Stop `
                        -ContentType 'application/x-www-form-urlencoded' `
                        -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
                        -Body $body

            $r.Token     = $tok.access_token
            $r.Refresh   = $tok.refresh_token
            $r.ExpiresIn = if ($tok.expires_in) { [int]$tok.expires_in } else { 3600 }
            $r.Success   = $true

            # Decode JWT payload to get signed-in UPN for display
            try {
                $p  = $tok.access_token.Split('.')[1]
                $p += '=' * ((4 - $p.Length % 4) % 4)
                $c  = [System.Text.Encoding]::UTF8.GetString(
                          [Convert]::FromBase64String($p.Replace('-','+').Replace('_','/'))
                      ) | ConvertFrom-Json
                $r.Account = if ($c.upn) { $c.upn } elseif ($c.preferred_username) { $c.preferred_username } else { $c.oid }
            } catch {}
        } catch {
            try { $listener.Stop() } catch {}
            $r.Error = $_.Exception.Message
        }
        return $r
    }

    $ps = [System.Management.Automation.PowerShell]::Create()
    [void]$ps.AddScript($authScript).AddParameters(@{
        clientId    = $script:GraphClient
        tenantId    = $script:GraphTenant
        scope       = $Scope
        redirectUri = $script:GraphRedirect
        verifier    = $verifier
    })
    $script:AuthPs     = $ps
    $script:AuthHandle = $ps.BeginInvoke()

    # Open the default browser to the Microsoft login page
    Start-Process $authUrl
    & $script:SetGraphStatus "Browser opened — sign in and return here." '#D9A441'
    & $script:SetConnectButtons $false
    & $script:WriteLog "Browser opened for Microsoft account sign-in (scopes: $Scope)." "INFO"

    # DispatcherTimer polls every 500 ms until the background runspace completes
    $t = [System.Windows.Threading.DispatcherTimer]::new()
    $t.Interval = [TimeSpan]::FromMilliseconds(500)
    $t.Add_Tick({
        if (-not $script:AuthPs) { $script:AuthTimer.Stop(); $script:AuthTimer = $null; return }
        $state = $script:AuthPs.InvocationStateInfo.State
        if ($state -notin @('Running','NotStarted')) {
            $script:AuthTimer.Stop()
            $script:AuthTimer = $null
            & $script:SetConnectButtons $true
            try {
                $res = $script:AuthPs.EndInvoke($script:AuthHandle) | Select-Object -Last 1
                if ($res -and $res.Success) {
                    $script:GraphToken   = $res.Token
                    $script:GraphRefresh = $res.Refresh
                    $script:GraphExpiry  = (Get-Date).AddSeconds($res.ExpiresIn - 60)
                    $script:GraphAccount = $res.Account
                    $script:EpmSchemaCache = @{}; $script:EpmRulesTemplate = $null   # new tenant/session
                    & $script:SetGraphStatus "Connected as: $($res.Account)" '#5FA88A'
                    $window.FindName('btnLoadElevationReport').IsEnabled = $true
                    & $script:WriteLog "Signed in as $($res.Account). Token valid until $($script:GraphExpiry.ToString('HH:mm:ss'))." "OK"
                    $scp = & $script:GetTokenScopes
                    if ($scp.Count -gt 0 -and ($scp -notcontains 'DeviceManagementConfiguration.ReadWrite.All')) {
                        & $script:WriteLog "This token can't create EPM rules (no DeviceManagementConfiguration.ReadWrite.All). Use 'Connect to Graph' on the Create Rule page." "WARN"
                    }
                } else {
                    & $script:SetGraphStatus "Sign-in failed: $($res.Error)" '#C1554A'
                    & $script:WriteLog "Graph sign-in failed: $($res.Error)" "ERR"
                }
            } catch {
                & $script:SetGraphStatus "Auth error: $($_.Exception.Message)" '#C1554A'
                & $script:WriteLog "Auth error: $($_.Exception.Message)" "ERR"
            }
            $script:AuthPs = $null; $script:AuthHandle = $null
        }
    })
    $script:AuthTimer = $t
    $t.Start()
}

$window.FindName('btnConnectGraph').Add_Click({
    & $script:StartGraphSignIn $window.FindName('txtTenantId').Text.Trim() $script:GraphScope
})

$window.FindName('btnRuleConnectGraph').Add_Click({
    & $script:StartGraphSignIn $window.FindName('txtRuleTenantId').Text.Trim() $script:GraphScopeRules
})

# Fetches all elevation events (all pages), keeps the raw events by id for
# the Create Rule page and returns the flattened rows used by the report.
$script:GetElevationEvents = {
    & $script:WriteLog "Fetching EPM elevation events from Microsoft Graph..."
    $allItems = @(& $script:GraphGetAll 'https://graph.microsoft.com/beta/deviceManagement/privilegeManagementElevations')
    $script:ElevationEventsRaw = @{}
    foreach ($ev in $allItems) { if ($ev.id) { $script:ElevationEventsRaw["$($ev.id)"] = $ev } }
    $results = @($allItems | ForEach-Object {
            $ev = $_
            $rawResult = "$($ev.result)"
            [PSCustomObject]@{
                EventDateTime   = $ev.eventDateTime
                DeviceName      = $ev.deviceName
                UPN             = $ev.upn
                ElevationType   = $ev.elevationType
                Result          = switch ($rawResult) {
                                      'succeeded'          { 'Succeeded' }
                                      'failed'             { 'Failed' }
                                      'timeout'            { 'Timeout' }
                                      'notAllowed'         { 'Not Allowed' }
                                      'unknown'            { 'Unknown' }
                                      'unknownFutureValue' { 'Unknown' }
                                      '0'                  { 'Unknown' }
                                      '1'                  { 'Succeeded' }
                                      '2'                  { 'Failed' }
                                      '3'                  { 'Timeout' }
                                      '4'                  { 'Not Allowed' }
                                      default              { $rawResult }
                                  }
                FilePath        = $ev.filePath
                FileDescription = $ev.fileDescription
                ProductName     = $ev.productName
                Publisher       = $ev.companyName
                FileVersion     = $ev.fileVersion
                ProcessType     = $ev.processType
                PolicyName      = $ev.policyName
                Justification   = $ev.justification
                UserType        = $ev.userType
                ParentProcess   = $ev.parentProcessName
                RuleId          = $ev.ruleId
                PolicyId        = $ev.policyId
                DeviceId        = $ev.deviceId
                InternalName    = $ev.internalName
                Hash            = $ev.hash
                Id              = $ev.id
            }
        })
    $script:ElevationEvents = $results
    return $results
}

$window.FindName('btnLoadElevationReport').Add_Click({
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        $results = @(& $script:GetElevationEvents)

        if ($results.Count -eq 0) {
            & $script:WriteLog "No elevation events returned." "WARN"
            $window.FindName('ResultGrid').ItemsSource = $null
            $window.FindName('RawOutput').Text         = ''
            $window.Cursor = [System.Windows.Input.Cursors]::Arrow
            return
        }

        & $script:WriteLog "Loaded $($results.Count) elevation event(s) — opening report window." "OK"

        # Serialize for the new STA runspace
        $json  = $results | ConvertTo-Json -Depth 5
        $count = $results.Count

        $gridScript = {
            param([string]$Json, [int]$Count, $Sync)
            Add-Type -AssemblyName PresentationFramework
            Add-Type -AssemblyName PresentationCore
            Add-Type -AssemblyName WindowsBase
            Add-Type -AssemblyName System.Windows.Forms

            $rawData = $Json | ConvertFrom-Json

            # Build DataTable (all string columns so RowFilter LIKE works)
            $dt    = New-Object System.Data.DataTable
            $items = @($rawData)
            if ($items.Count -gt 0) {
                $props = $items[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                foreach ($p in $props) { [void]$dt.Columns.Add($p) }
                foreach ($item in $items) {
                    $row = $dt.NewRow()
                    foreach ($p in $props) {
                        $v = $item.$p
                        $row[$p] = if ($null -eq $v) { '' } else { $v.ToString() }
                    }
                    $dt.Rows.Add($row)
                }
            }

            [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Height="700" Width="1300" MinHeight="400" MinWidth="700"
        WindowStartupLocation="CenterScreen"
        Background="#17181C" Foreground="#E8E6E1" FontFamily="Segoe UI">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Toolbar: filter + export -->
        <Border Grid.Row="0" Background="#1F2023" Padding="12,8"
                BorderBrush="#35363B" BorderThickness="0,0,0,1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="txtFilter"
                         Background="#26272B" Foreground="#E8E6E1"
                         CaretBrush="#C97B3D" BorderBrush="#35363B" BorderThickness="1"
                         Padding="8,7" FontSize="12" VerticalAlignment="Center"
                         ToolTip="Type to filter across all columns…"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="10,0,0,0">
                    <Button x:Name="btnCreateRule"
                            Content="Create rule from selection"
                            Background="#3A2A1C" Foreground="#F0C08A" BorderBrush="#C97B3D" BorderThickness="1"
                            Padding="14,8" Margin="0,0,8,0" FontSize="11"
                            FontWeight="SemiBold" Cursor="Hand"
                            ToolTip="Opens Create Rule in the main window, prefilled from the selected event"/>
                    <Button x:Name="btnExport"
                            Content="Export CSV"
                            Background="#C97B3D" Foreground="White" BorderThickness="0"
                            Padding="14,8" Margin="0,0,8,0" FontSize="11"
                            FontWeight="SemiBold" Cursor="Hand"/>
                    <Button x:Name="btnClose"
                            Content="Close"
                            Background="#35363B" Foreground="White" BorderThickness="0"
                            Padding="14,8" FontSize="11"
                            FontWeight="SemiBold" Cursor="Hand"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Results grid -->
        <DataGrid x:Name="dg" Grid.Row="1"
                  Background="#1F2023" Foreground="#E8E6E1"
                  BorderBrush="#35363B" BorderThickness="0"
                  GridLinesVisibility="Horizontal" HorizontalGridLinesBrush="#35363B"
                  RowBackground="#1F2023" AlternatingRowBackground="#232428"
                  FontSize="12" AutoGenerateColumns="True" IsReadOnly="True"
                  SelectionMode="Single" HeadersVisibility="Column"
                  CanUserResizeRows="False" HorizontalScrollBarVisibility="Auto"
                  VerticalScrollBarVisibility="Auto">
            <DataGrid.ColumnHeaderStyle>
                <Style TargetType="DataGridColumnHeader">
                    <Setter Property="Background"       Value="#26272B"/>
                    <Setter Property="Foreground"       Value="#A3A29E"/>
                    <Setter Property="Padding"          Value="10,6"/>
                    <Setter Property="FontSize"         Value="11"/>
                    <Setter Property="FontWeight"       Value="SemiBold"/>
                    <Setter Property="BorderBrush"      Value="#35363B"/>
                    <Setter Property="BorderThickness"  Value="0,0,0,1"/>
                </Style>
            </DataGrid.ColumnHeaderStyle>
            <DataGrid.CellStyle>
                <Style TargetType="DataGridCell">
                    <Setter Property="BorderThickness" Value="0"/>
                    <Setter Property="Padding"         Value="10,5"/>
                    <Setter Property="Foreground"      Value="#E8E6E1"/>
                    <Style.Triggers>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter Property="Background" Value="#35363B"/>
                        </Trigger>
                    </Style.Triggers>
                </Style>
            </DataGrid.CellStyle>
        </DataGrid>

        <!-- Status bar -->
        <Border Grid.Row="2" Background="#1F2023" Padding="12,6"
                BorderBrush="#35363B" BorderThickness="0,1,0,0">
            <TextBlock x:Name="lblStatus" FontSize="11" FontFamily="Consolas"
                       Foreground="#6B6A66"/>
        </Border>
    </Grid>
</Window>
'@
            $reader = [System.Xml.XmlNodeReader]::new($xaml)
            $w      = [System.Windows.Markup.XamlReader]::Load($reader)
            $w.Title = "EPM Elevation Events — $Count record(s)"

            $dg  = $w.FindName('dg')
            $lbl = $w.FindName('lblStatus')
            $txt = $w.FindName('txtFilter')

            $dg.ItemsSource = $dt.DefaultView
            $lbl.Text       = "$Count record(s)"

            # Live filter across all string columns
            $txt.Add_TextChanged({
                $f = $txt.Text.Trim().Replace("'", "''")
                if ($f) {
                    $conds = ($dt.Columns | ForEach-Object { "[$($_.ColumnName)] LIKE '%$f%'" }) -join ' OR '
                    try   { $dt.DefaultView.RowFilter = $conds }
                    catch { $dt.DefaultView.RowFilter = '' }
                } else {
                    $dt.DefaultView.RowFilter = ''
                }
                $lbl.Text = "$($dt.DefaultView.Count) of $($dt.Rows.Count) record(s)"
            }.GetNewClosure())

            $w.FindName('btnExport').Add_Click({
                $sfd          = [System.Windows.Forms.SaveFileDialog]::new()
                $sfd.Filter   = 'CSV Files (*.csv)|*.csv'
                $sfd.FileName = "EPM-Elevations-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
                if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $rawData | Export-Csv -Path $sfd.FileName -NoTypeInformation -Encoding UTF8
                }
            }.GetNewClosure())

            # Hand the selected event to the main window (polled by its timer)
            $w.FindName('btnCreateRule').Add_Click({
                $sel = $dg.SelectedItem
                if ($null -eq $sel) { $lbl.Text = 'Select an event first.'; return }
                $id = "$($sel.Row['Id'])"
                if (-not $id) { $lbl.Text = 'This row has no event id.'; return }
                $Sync.PendingEventId = $id
                $lbl.Text = "Sent to Create Rule: $($sel.Row['FilePath'])"
            }.GetNewClosure())

            $w.FindName('btnClose').Add_Click({ $w.Close() })

            [void]$w.ShowDialog()
        }

        $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.ThreadOptions  = 'ReuseThread'
        $rs.Open()
        $ps2 = [System.Management.Automation.PowerShell]::Create()
        $ps2.Runspace = $rs
        [void]$ps2.AddScript($gridScript).AddParameters(@{ Json = $json; Count = $count; Sync = $script:Sync })
        [void]$ps2.BeginInvoke()

    } catch {
        & $script:WriteLog "Error fetching elevation events: $($_.Exception.Message)" "ERR"
    }
    $window.Cursor = [System.Windows.Input.Cursors]::Arrow
})

# =============================================================
# INTUNE — EPM elevation rules via Microsoft Graph (beta)
#
# Elevation rules policies are Settings Catalog policies. All rules of
# a policy live in ONE group-collection setting
#   device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}
# and every rule is one entry in its groupSettingCollectionValue.
#
# Setting/option IDs are resolved at runtime from the tenant's own
# setting definitions (template settingTemplates + configurationSettings),
# with known IDs as fallback, so the payload follows what Intune expects.
# =============================================================
$script:EpmRoot        = 'device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}'
$script:EpmFamily      = 'endpointSecurityEndpointPrivilegeManagement'
$script:EpmEmptySchema = @{ TemplateId = $null; Defs = @{}; InstTpl = @{}; ValTpl = @{}; Loaded = $false }
$script:EpmQuiet       = $false

$script:EpmWarn = {
    param([string]$Message)
    if (-not $script:EpmQuiet) { & $script:WriteLog $Message "WARN" }
}

# ---- Graph plumbing -----------------------------------------
$script:EnsureGraphToken = {
    if (-not $script:GraphToken) { throw "Not connected to Microsoft Graph. Click 'Connect to Graph' first." }
    if ($script:GraphRefresh -and (Get-Date) -ge $script:GraphExpiry) {
        & $script:WriteLog "Access token expired — refreshing silently..." "INFO"
        $body = "client_id=$([System.Uri]::EscapeDataString($script:GraphClient))" +
                "&refresh_token=$([System.Uri]::EscapeDataString($script:GraphRefresh))" +
                "&grant_type=refresh_token" +
                "&scope=$([System.Uri]::EscapeDataString($script:GraphScopeActive))"
        $tok = Invoke-RestMethod -Method POST -ErrorAction Stop `
                   -ContentType 'application/x-www-form-urlencoded' `
                   -Uri "https://login.microsoftonline.com/$($script:GraphTenant)/oauth2/v2.0/token" `
                   -Body $body
        $script:GraphToken  = $tok.access_token
        if ($tok.refresh_token) { $script:GraphRefresh = $tok.refresh_token }
        $script:GraphExpiry = (Get-Date).AddSeconds([int]$tok.expires_in - 60)
        & $script:WriteLog "Token refreshed. Valid until $($script:GraphExpiry.ToString('HH:mm:ss'))." "OK"
    }
}

# Invoke a Graph request. Relative URIs go to /beta. Body may be a JSON string or an object.
$script:InvokeGraph = {
    param([string]$Method = 'GET', [string]$Uri, $Body = $null)
    & $script:EnsureGraphToken
    if ($Uri -notmatch '^https://') { $Uri = "https://graph.microsoft.com/beta$Uri" }
    $p = @{
        Method      = $Method
        Uri         = $Uri
        ErrorAction = 'Stop'
        Headers     = @{ Authorization = "Bearer $($script:GraphToken)" }
    }
    if ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { ConvertTo-Json -InputObject $Body -Depth 64 -Compress }
        $p.Body        = [System.Text.Encoding]::UTF8.GetBytes($json)
        $p.ContentType = 'application/json; charset=utf-8'
    }
    try {
        Invoke-RestMethod @p
    } catch {
        $msg    = $_.Exception.Message
        $detail = $null
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detail = $_.ErrorDetails.Message }
        if (-not $detail) {
            try {
                $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $detail = $sr.ReadToEnd()
            } catch {}
        }
        if ($detail) {
            try { $j = $detail | ConvertFrom-Json; if ($j.error.message) { $detail = $j.error.message } } catch {}
            $msg = "$msg`n$detail"
        }
        throw "Graph $Method $Uri failed: $msg"
    }
}

# GET all pages of a collection; emits the items
$script:GraphGetAll = {
    param([string]$Uri)
    $next = $Uri
    while ($next) {
        $r = & $script:InvokeGraph 'GET' $next
        if ($null -ne $r.value) { foreach ($i in @($r.value)) { $i } }
        $next = $r.'@odata.nextLink'
    }
}

# ---- Template & setting definitions -------------------------
$script:EpmFindTemplate = {
    if ($script:EpmRulesTemplate) { return $script:EpmRulesTemplate }
    $tpls = @()
    try {
        $tpls = @(& $script:GraphGetAll "/deviceManagement/configurationPolicyTemplates?`$filter=templateFamily eq '$($script:EpmFamily)'")
    } catch {
        & $script:WriteLog "Template filter not accepted, scanning all templates..." "WARN"
        $tpls = @(& $script:GraphGetAll "/deviceManagement/configurationPolicyTemplates?`$top=500")
    }
    $c = @($tpls | Where-Object {
            "$($_.templateFamily)" -eq $script:EpmFamily -and
            "$($_.displayName)" -match 'rule' -and
            "$($_.lifecycleState)" -ne 'deprecated'
         } | Sort-Object { [int]$_.version } -Descending)
    if ($c.Count -eq 0) { throw "The 'Elevation rules policy' template wasn't found. Is Endpoint Privilege Management licensed in this tenant?" }
    $script:EpmRulesTemplate = $c[0]
    & $script:WriteLog "Using template '$($c[0].displayName)' v$($c[0].version) ($($c[0].id))." "INFO"
    return $c[0]
}

# Collects settingDefinitionId -> settingInstanceTemplateId / settingValueTemplateId
$script:EpmWalkTemplate = {
    param($Node, $Schema)
    if ($null -eq $Node) { return }
    if ($Node -is [System.Array]) { foreach ($n in $Node) { & $script:EpmWalkTemplate $n $Schema }; return }
    if ($Node -isnot [System.Management.Automation.PSCustomObject]) { return }
    $defId  = "$($Node.settingDefinitionId)"
    $instId = "$($Node.settingInstanceTemplateId)"
    if ($defId -and $instId -and -not $Schema.InstTpl.ContainsKey($defId)) { $Schema.InstTpl[$defId] = $instId }
    foreach ($p in $Node.PSObject.Properties) {
        $v = $p.Value
        if ($null -eq $v) { continue }
        if ($defId -and $p.Name -like '*ValueTemplate' -and $v -is [System.Management.Automation.PSCustomObject] -and $v.settingValueTemplateId) {
            if (-not $Schema.ValTpl.ContainsKey($defId)) { $Schema.ValTpl[$defId] = "$($v.settingValueTemplateId)" }
        }
        if ($v -is [System.Array] -or $v -is [System.Management.Automation.PSCustomObject]) { & $script:EpmWalkTemplate $v $Schema }
    }
}

$script:EpmLoadSchema = {
    param([string]$TemplateId)
    if (-not $TemplateId) { return $script:EpmEmptySchema }
    if ($script:EpmSchemaCache.ContainsKey($TemplateId)) { return $script:EpmSchemaCache[$TemplateId] }
    $schema = @{ TemplateId = $TemplateId; Defs = @{}; InstTpl = @{}; ValTpl = @{}; Loaded = $false }
    & $script:WriteLog "Reading EPM setting definitions for template $TemplateId..." "INFO"
    try {
        $st = @(& $script:GraphGetAll "/deviceManagement/configurationPolicyTemplates('$TemplateId')/settingTemplates?`$expand=settingDefinitions")
        foreach ($s in $st) {
            foreach ($d in @($s.settingDefinitions)) { if ($d -and $d.id) { $schema.Defs["$($d.id)"] = $d } }
            & $script:EpmWalkTemplate $s.settingInstanceTemplate $schema
        }
    } catch {
        & $script:WriteLog "Couldn't read template definitions: $($_.Exception.Message)" "WARN"
    }
    # Fill in anything missing (root, children, dependent settings) one by one
    $queue = New-Object System.Collections.Generic.Queue[string]
    $queue.Enqueue($script:EpmRoot)
    $seen = @{}
    while ($queue.Count -gt 0) {
        $id = $queue.Dequeue()
        if ($seen.ContainsKey($id)) { continue }
        $seen[$id] = $true
        if (-not $schema.Defs.ContainsKey($id)) {
            try { $schema.Defs[$id] = & $script:InvokeGraph 'GET' "/deviceManagement/configurationSettings('$([System.Uri]::EscapeDataString($id))')" }
            catch { continue }
        }
        $d = $schema.Defs[$id]
        foreach ($c in @($d.childIds)) { if ($c) { $queue.Enqueue("$c") } }
        foreach ($o in @($d.options)) { foreach ($dep in @($o.dependedOnBy)) { if ($dep -and $dep.dependedOnBy) { $queue.Enqueue("$($dep.dependedOnBy)") } } }
    }
    $schema.Loaded = $schema.Defs.ContainsKey($script:EpmRoot)
    if ($schema.Loaded) { & $script:WriteLog "Loaded $($schema.Defs.Count) EPM setting definitions." "OK" }
    else { & $script:WriteLog "EPM setting definitions unavailable — falling back to built-in setting IDs." "WARN" }
    $script:EpmSchemaCache[$TemplateId] = $schema
    return $schema
}

# ---- ID resolution ------------------------------------------
$script:EpmChildId = {
    param($Schema, [string]$Suffix)
    $want = "$($script:EpmRoot)_$Suffix"
    $root = $Schema.Defs[$script:EpmRoot]
    if ($root -and $root.childIds) {
        $ids = @($root.childIds | ForEach-Object { "$_" })
        if ($ids -contains $want) { return $want }
        $hit = $ids | Where-Object { $_ -like "*_$Suffix" } | Select-Object -First 1
        if ($hit) { return $hit }
    }
    return $want
}

$script:EpmOption = {
    param($Schema, [string]$DefId, [string[]]$Suffixes, [string]$NamePattern, [string]$Fallback)
    $d = $Schema.Defs[$DefId]
    if ($d -and $d.options) {
        $opts = @($d.options)
        foreach ($s in @($Suffixes)) {
            if (-not $s) { continue }
            $o = $opts | Where-Object { "$($_.itemId)" -like "*_$s" } | Select-Object -First 1
            if ($o) { return $o }
        }
        if ($NamePattern) {
            $o = $opts | Where-Object { "$($_.displayName)" -match $NamePattern } | Select-Object -First 1
            if ($o) { return $o }
        }
        & $script:EpmWarn "No option '$($Suffixes -join '/')' on $DefId — using $Fallback"
    }
    return [pscustomobject]@{ itemId = $Fallback; displayName = ''; dependedOnBy = @() }
}

$script:EpmDepIds = {
    param($Option)
    @(@($Option.dependedOnBy) | Where-Object { $_ -and $_.dependedOnBy } | ForEach-Object { "$($_.dependedOnBy)" })
}

$script:EpmDepId = {
    param($Option, [string]$Like, [string]$Fallback)
    $hit = @(& $script:EpmDepIds $Option) | Where-Object { $_ -like $Like } | Select-Object -First 1
    if ($hit) { return $hit }
    return $Fallback
}

# ---- Setting instance builders ------------------------------
$script:EpmAddTpl = {
    param($Schema, $Inst, [string]$ValueProp)
    $id = $Inst.settingDefinitionId
    if ($Schema.InstTpl.ContainsKey($id)) {
        $Inst['settingInstanceTemplateReference'] = [ordered]@{ settingInstanceTemplateId = $Schema.InstTpl[$id] }
    }
    if ($ValueProp -and $Schema.ValTpl.ContainsKey($id) -and $Inst[$ValueProp]) {
        $Inst[$ValueProp]['settingValueTemplateReference'] = [ordered]@{ settingValueTemplateId = $Schema.ValTpl[$id]; useTemplateDefault = $false }
    }
}

$script:EpmSimple = {
    param($Schema, [string]$DefId, [string]$Value, [bool]$WithTpl, [bool]$Reference)
    $vt = if ($Reference) { '#microsoft.graph.deviceManagementConfigurationReferenceSettingValue' }
          else            { '#microsoft.graph.deviceManagementConfigurationStringSettingValue' }
    $inst = [ordered]@{
        '@odata.type'       = '#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance'
        settingDefinitionId = $DefId
        simpleSettingValue  = [ordered]@{ '@odata.type' = $vt; value = $Value }
    }
    if ($WithTpl) { & $script:EpmAddTpl $Schema $inst 'simpleSettingValue' }
    $inst
}

$script:EpmChoice = {
    param($Schema, [string]$DefId, [string]$ValueId, $Children, [bool]$WithTpl)
    # foreach (not @()) — @() on a List of dictionaries throws "Argument types do not match"
    $kids = @()
    if ($null -ne $Children) { $kids = @(foreach ($c in $Children) { $c }) }
    $inst = [ordered]@{
        '@odata.type'       = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
        settingDefinitionId = $DefId
        choiceSettingValue  = [ordered]@{
            '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
            value         = $ValueId
            children      = $kids
        }
    }
    if ($WithTpl) { & $script:EpmAddTpl $Schema $inst 'choiceSettingValue' }
    $inst
}

$script:EpmChoiceCollection = {
    param($Schema, [string]$DefId, [string[]]$ValueIds, [bool]$WithTpl)
    $vals = @(foreach ($v in $ValueIds) {
        [ordered]@{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'; value = $v; children = @() }
    })
    $inst = [ordered]@{
        '@odata.type'                = '#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance'
        settingDefinitionId          = $DefId
        choiceSettingCollectionValue = $vals
    }
    if ($WithTpl) { & $script:EpmAddTpl $Schema $inst $null }
    $inst
}

# Builds ONE rule (an entry of groupSettingCollectionValue) from the form model.
# $WithTpl adds template references (used for the first rule of a new policy).
$script:EpmBuildRuleValue = {
    param($Schema, $M, [bool]$WithTpl)
    if (-not $Schema) { $Schema = $script:EpmEmptySchema }
    $R          = $script:EpmRoot
    $children   = New-Object System.Collections.Generic.List[object]
    $deferredCp = $null

    # Applies to (Intune only offers "all users")
    $atId  = & $script:EpmChildId $Schema 'appliesto'
    $atOpt = & $script:EpmOption $Schema $atId @('allusers') 'all users' "$($R)_allusers"
    $children.Add((& $script:EpmChoice $Schema $atId $atOpt.itemId $null $WithTpl))

    # Plain string settings. Empty values are left out (Intune rejects empty strings).
    $simple = [ordered]@{
        name            = $M.Name
        description     = $M.Description
        filename        = $M.FileName
        filepath        = $M.FilePath
        filehash        = $M.FileHash
        fileversion     = $M.MinVersion
        productname     = $M.ProductName
        internalname    = $M.InternalName
        filedescription = $M.FileDescription
    }
    foreach ($k in @($simple.Keys)) {
        $v = "$($simple[$k])".Trim()
        if ($k -eq 'filehash') { $v = $v.ToUpperInvariant() }
        if ($v) { $children.Add((& $script:EpmSimple $Schema (& $script:EpmChildId $Schema $k) $v $WithTpl $false)) }
    }

    # Signature source (Not configured = setting left out)
    if ("$($M.SigSource)" -in @('upload','reusable')) {
        $ssId = & $script:EpmChildId $Schema 'signaturesource'
        if ($M.SigSource -eq 'upload') { $ssOpt = & $script:EpmOption $Schema $ssId @('1') 'upload' "$($R)_signaturesource_1" }
        else                           { $ssOpt = & $script:EpmOption $Schema $ssId @('0') 'reusable' "$($R)_signaturesource_0" }
        $sigKids = New-Object System.Collections.Generic.List[object]
        if ($M.SigSource -eq 'upload') {
            $cfId = & $script:EpmDepId $ssOpt '*certificatefileupload*' "$($R)_certificatefileupload"
            $sigKids.Add((& $script:EpmSimple $Schema $cfId "$($M.CertBase64)" $WithTpl $false))
        } else {
            $crId = & $script:EpmDepId $ssOpt '*certificatepayloadwithreusablesetting*' "$($R)_certificatepayloadwithreusablesetting"
            $sigKids.Add((& $script:EpmSimple $Schema $crId "$($M.ReusableId)" $WithTpl $true))
        }
        $ctId = & $script:EpmDepId $ssOpt '*certificatetype*' "$($R)_certificatetype"
        if ($M.CertType -eq 'ca') { $ctOpt = & $script:EpmOption $Schema $ctId @('issuingauthority','certificateauthority') 'authority' "$($R)_issuingauthority" }
        else                      { $ctOpt = & $script:EpmOption $Schema $ctId @('publisher') 'publisher' "$($R)_publisher" }
        $sigKids.Add((& $script:EpmChoice $Schema $ctId $ctOpt.itemId $null $WithTpl))
        $children.Add((& $script:EpmChoice $Schema $ssId $ssOpt.itemId $sigKids $WithTpl))
    }

    # Elevation type
    $rtId = & $script:EpmChildId $Schema 'ruletype'
    switch ("$($M.ElevationType)") {
        'automatic'   { $rtOpt = & $script:EpmOption $Schema $rtId @('automatic')         '^automatic'   "$($R)_automatic" }
        'support'     { $rtOpt = & $script:EpmOption $Schema $rtId @('supportarbitrated') 'support'      "$($R)_supportarbitrated" }
        'currentuser' { $rtOpt = & $script:EpmOption $Schema $rtId @('userconfirmeduser') 'current user' "$($R)_userconfirmeduser" }
        'deny'        { $rtOpt = & $script:EpmOption $Schema $rtId @('deny')              '^deny'        "$($R)_deny" }
        default       { $rtOpt = & $script:EpmOption $Schema $rtId @('self')              'user confirm' "$($R)_self" }
    }
    $rtKids = New-Object System.Collections.Generic.List[object]

    # Validation (User confirmed: optional; Elevate as current user: Windows authentication)
    if ("$($M.ElevationType)" -in @('self','currentuser')) {
        $valFallback = if ($M.ElevationType -eq 'self') { "$($R)_ruletype_validation" } else { $null }
        $valId = & $script:EpmDepId $rtOpt '*validation*' $valFallback
        if ($valId) {
            $want = @()
            if ($M.ElevationType -eq 'self') {
                if ($M.ValJustification) { $want += 'just' }
                if ($M.ValWinAuth)       { $want += 'auth' }
            } else { $want = @('auth') }
            $vals = @()
            foreach ($w in $want) {
                if ($w -eq 'just') { $o = & $script:EpmOption $Schema $valId @() 'justification'  "$($R)_ruletype_validation_0" }
                else               { $o = & $script:EpmOption $Schema $valId @() 'authentication' "$($R)_ruletype_validation_1" }
                $vals += "$($o.itemId)"
            }
            if ($vals.Count -gt 0) {
                $vd = $Schema.Defs[$valId]
                if ($vd -and "$($vd.'@odata.type')" -notmatch 'Collection') {
                    $rtKids.Add((& $script:EpmChoice $Schema $valId $vals[0] $null $WithTpl))
                } else {
                    $rtKids.Add((& $script:EpmChoiceCollection $Schema $valId $vals $WithTpl))
                }
            }
        } else {
            & $script:EpmWarn "Couldn't resolve the validation setting for 'Elevate as current user'; Intune may reject the rule."
        }
    }

    # Child process behaviour (not used for Deny). It may hang under the rule type option.
    if ("$($M.ElevationType)" -ne 'deny') {
        $cpId  = & $script:EpmChildId $Schema 'childprocessbehavior'
        $cpDep = @(& $script:EpmDepIds $rtOpt) | Where-Object { $_ -like '*childprocess*' } | Select-Object -First 1
        if ($cpDep) { $cpId = $cpDep }
        switch ("$($M.ChildProcess)") {
            'allow' { $cpOpt = & $script:EpmOption $Schema $cpId @('allowrunelevated')             'allow all' "$($R)_allowrunelevated" }
            'deny'  { $cpOpt = & $script:EpmOption $Schema $cpId @('deny')                         'deny'      "$($R)_childprocessbehavior_deny" }
            default { $cpOpt = & $script:EpmOption $Schema $cpId @('allowrunelevatedrulerequired') 'require'   "$($R)_allowrunelevatedrulerequired" }
        }
        $cpInst = & $script:EpmChoice $Schema $cpId $cpOpt.itemId $null $WithTpl
        if ($cpDep) { $rtKids.Add($cpInst) } else { $deferredCp = $cpInst }
    }

    $children.Add((& $script:EpmChoice $Schema $rtId $rtOpt.itemId $rtKids $WithTpl))
    if ($deferredCp) { $children.Add($deferredCp) }

    $val = [ordered]@{ children = $children.ToArray() }
    if ($WithTpl -and $Schema.ValTpl.ContainsKey($R)) {
        $val['settingValueTemplateReference'] = [ordered]@{ settingValueTemplateId = $Schema.ValTpl[$R]; useTemplateDefault = $false }
    }
    return $val
}

# The policy-level setting that holds the rules (new policies only)
$script:EpmBuildRootSetting = {
    param($Schema, $Values, [bool]$WithTpl)
    $inst = [ordered]@{
        '@odata.type'               = '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance'
        settingDefinitionId         = $script:EpmRoot
        groupSettingCollectionValue = @($Values)
    }
    if ($WithTpl -and $Schema.InstTpl.ContainsKey($script:EpmRoot)) {
        $inst['settingInstanceTemplateReference'] = [ordered]@{ settingInstanceTemplateId = $Schema.InstTpl[$script:EpmRoot] }
    }
    [ordered]@{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'; settingInstance = $inst }
}

# ---- Reading existing policies ------------------------------
$script:EpmFlatten = {
    param($Instances, $Out)
    $pre = "$($script:EpmRoot)_"
    foreach ($i in @($Instances)) {
        if ($null -eq $i) { continue }
        $k = "$($i.settingDefinitionId)".Replace($pre, '')
        if ($null -ne $i.simpleSettingValue) {
            $Out[$k] = "$($i.simpleSettingValue.value)"
        } elseif ($null -ne $i.choiceSettingValue) {
            $Out[$k] = "$($i.choiceSettingValue.value)".Replace($pre, '')
            & $script:EpmFlatten $i.choiceSettingValue.children $Out
        } elseif ($null -ne $i.choiceSettingCollectionValue) {
            $Out[$k] = (@($i.choiceSettingCollectionValue) | ForEach-Object { "$($_.value)".Replace($pre, '') }) -join ', '
        }
    }
}

$script:EpmFriendly = {
    param([string]$Value)
    $v = "$Value"
    switch -Regex ($v) {
        'userconfirmeduser$'            { return 'Elevate as current user' }
        'supportarbitrated$'            { return 'Support approved' }
        '(^|_)self$'                    { return 'User confirmed' }
        '(^|_)automatic$'               { return 'Automatic' }
        'allowrunelevatedrulerequired$' { return 'Require rule to elevate' }
        'allowrunelevated$'             { return 'Allow all' }
        '(^|_)deny$'                    { return 'Deny' }
        'signaturesource_0$'            { return 'Reusable certificate' }
        'signaturesource_1$'            { return 'Uploaded certificate' }
        'issuingauthority$'             { return 'Certificate authority' }
        '(^|_)publisher$'               { return 'Publisher' }
    }
    return $v
}

$script:EpmParseRules = {
    param($Settings)
    $rootSetting = @($Settings) | Where-Object { $_.settingInstance.settingDefinitionId -eq $script:EpmRoot } | Select-Object -First 1
    if (-not $rootSetting) { return }
    $n = 0
    foreach ($gv in @($rootSetting.settingInstance.groupSettingCollectionValue)) {
        $n++
        $f = @{}
        & $script:EpmFlatten $gv.children $f
        $valKey = @($f.Keys | Where-Object { $_ -like '*validation*' }) | Select-Object -First 1
        [pscustomobject]@{
            No              = $n
            RuleName        = $f['name']
            FileName        = $f['filename']
            ElevationType   = & $script:EpmFriendly $f['ruletype']
            Validation      = if ($valKey) {
                                  (($f[$valKey] -split ',\s*') | ForEach-Object {
                                      if ($_ -match 'validation_0$') { 'Business justification' }
                                      elseif ($_ -match 'validation_1$') { 'Windows authentication' }
                                      else { $_ } }) -join ', '
                              } else { '' }
            ChildProcess    = & $script:EpmFriendly $f['childprocessbehavior']
            FilePath        = $f['filepath']
            MinVersion      = $f['fileversion']
            FileHash        = $f['filehash']
            Signature       = & $script:EpmFriendly $f['signaturesource']
            CertificateType = & $script:EpmFriendly $f['certificatetype']
            ProductName     = $f['productname']
            Description     = $f['description']
        }
    }
}

$script:EpmGetRulePolicies = {
    $sel = 'id,name,description,lastModifiedDateTime,settingCount,templateReference,roleScopeTagIds'
    try {
        $all = @(& $script:GraphGetAll "/deviceManagement/configurationPolicies?`$select=$sel&`$filter=templateReference/TemplateFamily eq '$($script:EpmFamily)'")
    } catch {
        & $script:WriteLog "Filtered policy query not accepted, listing all policies instead..." "WARN"
        $all = @(& $script:GraphGetAll "/deviceManagement/configurationPolicies?`$select=$sel")
    }
    @($all | Where-Object {
        "$($_.templateReference.templateFamily)" -eq $script:EpmFamily -and
        "$($_.templateReference.templateDisplayName)" -match 'rule'
    } | Sort-Object name)
}

$script:EpmGetPolicyFull = {
    param([string]$Id)
    $pol      = & $script:InvokeGraph 'GET' "/deviceManagement/configurationPolicies('$Id')"
    $settings = @(& $script:GraphGetAll "/deviceManagement/configurationPolicies('$Id')/settings")
    [pscustomobject]@{ Policy = $pol; Settings = $settings }
}

# ---- Rule model checks --------------------------------------
$script:RuleValidate = {
    param($M)
    $errors = New-Object System.Collections.Generic.List[string]
    $warns  = New-Object System.Collections.Generic.List[string]
    $name = "$($M.Name)".Trim(); $file = "$($M.FileName)".Trim(); $hash = "$($M.FileHash)".Trim(); $ver = "$($M.MinVersion)".Trim()
    if (-not $name) { $errors.Add('Rule name is required.') }
    if (-not $file) { $errors.Add('File name is required.') }
    elseif ($file -match '[\\/]') { $errors.Add('File name must not contain a folder — put that in File path.') }
    if ($hash -and $hash -notmatch '^[0-9A-Fa-f]{64}$') { $errors.Add('File hash must be a SHA-256 hash (64 hex characters).') }
    if ("$($M.SigSource)" -eq 'none' -and -not $hash) { $errors.Add('Intune needs a file hash when no certificate is used.') }
    if ("$($M.SigSource)" -eq 'upload' -and -not $M.CertBase64) { $errors.Add('Load a certificate for "Upload certificate".') }
    if ("$($M.SigSource)" -eq 'reusable' -and -not $M.ReusableId) { $errors.Add('Pick a reusable certificate.') }
    if ($ver -and $ver -notmatch '^\d+(\.\d+){0,3}$') { $errors.Add('Minimum version must look like 1.2.3.4.') }
    if ("$($M.ElevationType)" -eq 'automatic' -and "$($M.SigSource)" -eq 'none') { $warns.Add('Automatic elevation on a hash only. Consider adding a publisher certificate.') }
    if ("$($M.ChildProcess)" -eq 'allow' -and "$($M.ElevationType)" -ne 'deny') { $warns.Add('"Allow all" lets every child process run elevated (e.g. a file dialog opening a shell).') }
    if (-not "$($M.FilePath)".Trim()) { $warns.Add('No file path: the rule matches this file name in any folder.') }
    [pscustomobject]@{ Errors = $errors.ToArray(); Warnings = $warns.ToArray() }
}

$script:RuleStrength = {
    param($M)
    $pts = 0; $parts = @(); $tips = @()
    $hasHash = [bool]"$($M.FileHash)".Trim()
    $hasCert = ("$($M.SigSource)" -ne 'none') -and ($M.CertBase64 -or $M.ReusableId)
    if ($hasHash) { $pts += 2; $parts += 'hash'; $tips += 'The hash pins this exact build, so app updates need a new rule.' }
    if ($hasCert) {
        if ("$($M.CertType)" -eq 'ca') { $pts += 1; $parts += 'CA cert' } else { $pts += 2; $parts += 'publisher' }
    } else { $tips += 'Add a publisher certificate so the rule keeps working after updates.' }
    if ("$($M.FilePath)".Trim()) { $pts += 1; $parts += 'path' }
    if ("$($M.MinVersion)".Trim() -or "$($M.ProductName)".Trim() -or "$($M.InternalName)".Trim()) { $pts += 1; $parts += 'file info' }
    if ($hasHash -and $hasCert) { $tips += 'With a publisher certificate you could drop the hash and keep a minimum version.' }
    $bars  = if ($pts -ge 6) { 4 } elseif ($pts -ge 4) { 3 } elseif ($pts -ge 2) { 2 } elseif ($pts -ge 1) { 1 } else { 0 }
    $word  = @('Very weak','Weak','Fair','Good','Strong')[$bars]
    $label = if ($parts.Count) { "$word — $($parts -join ' + ')" } else { "$word — file name only" }
    [pscustomobject]@{ Bars = $bars; Label = $label; Tips = $tips }
}


# ---- Create Rule page: helpers ------------------------------
$script:BrushOf = { param([string]$Hex) [System.Windows.Media.BrushConverter]::new().ConvertFromString($Hex) }

$script:ToDataTable = {
    param($Rows, [string[]]$Columns)
    $dt = New-Object System.Data.DataTable
    foreach ($c in $Columns) { [void]$dt.Columns.Add($c) }
    foreach ($r in @($Rows)) {
        if ($null -eq $r) { continue }
        $row = $dt.NewRow()
        foreach ($c in $Columns) { $v = $r.$c; $row[$c] = if ($null -eq $v) { '' } else { "$v" } }
        [void]$dt.Rows.Add($row)
    }
    , $dt
}

$script:FormatDate = {
    param($Value)
    if (-not $Value) { return '' }
    try { return ([datetime]$Value).ToLocalTime().ToString('yyyy-MM-dd HH:mm') } catch { return "$Value" }
}

$script:CertSummary = {
    param($Cert)
    if (-not $Cert) { return '' }
    "$($Cert.Subject)  ·  thumbprint $($Cert.Thumbprint.Substring(0,8))…  ·  valid to $($Cert.NotAfter.ToString('yyyy-MM-dd'))"
}

$script:SetResult = {
    param([string]$Text, [string]$Kind)   # ok | err | info
    $panel = $window.FindName('panelPushResult'); $lbl = $window.FindName('lblPushResult')
    $c = switch ($Kind) {
        'ok'    { @('#1F2B26','#2F4A3E','#8FD0B2') }
        'err'   { @('#2B1F1F','#4A2F2F','#E57A6E') }
        default { @('#1C1D21','#35363B','#E8E6E1') }
    }
    $panel.Background  = & $script:BrushOf $c[0]
    $panel.BorderBrush = & $script:BrushOf $c[1]
    $lbl.Foreground    = & $script:BrushOf $c[2]
    $lbl.Text          = $Text
    $panel.Visibility  = 'Visible'
}

# ---- Form <-> model -----------------------------------------
$script:RuleTextMap = [ordered]@{
    txtRuleName        = 'Name'
    txtRuleDesc        = 'Description'
    txtFileName        = 'FileName'
    txtFilePath        = 'FilePath'
    txtFileHash        = 'FileHash'
    txtMinVersion      = 'MinVersion'
    txtProductName     = 'ProductName'
    txtInternalName    = 'InternalName'
    txtFileDescription = 'FileDescription'
}

$script:RuleReadForm = {
    $m = [ordered]@{}
    foreach ($k in $script:RuleTextMap.Keys) { $m[$script:RuleTextMap[$k]] = "$($window.FindName($k).Text)".Trim() }
    $m.SigSource = if ($window.FindName('rbSigUpload').IsChecked) { 'upload' } elseif ($window.FindName('rbSigReusable').IsChecked) { 'reusable' } else { 'none' }
    $m.CertBase64   = $script:RuleCertBase64
    $m.CertSubject  = $script:RuleCertInfo
    $m.CertType     = if ($window.FindName('rbCertCA').IsChecked) { 'ca' } else { 'publisher' }
    $m.ReusableId   = $script:RuleReusableId
    $m.ReusableName = $script:RuleReusableName
    $m.ElevationType = if     ($window.FindName('rbElAuto').IsChecked)    { 'automatic' }
                       elseif ($window.FindName('rbElSupport').IsChecked) { 'support' }
                       elseif ($window.FindName('rbElCurrent').IsChecked) { 'currentuser' }
                       elseif ($window.FindName('rbElDeny').IsChecked)    { 'deny' }
                       else { 'self' }
    $m.ValJustification = [bool]$window.FindName('chkValJustification').IsChecked
    $m.ValWinAuth       = [bool]$window.FindName('chkValWinAuth').IsChecked
    $m.ChildProcess = if ($window.FindName('rbChildAllow').IsChecked) { 'allow' } elseif ($window.FindName('rbChildDeny').IsChecked) { 'deny' } else { 'rule' }
    $m
}

$script:RuleWriteForm = {
    param($M)
    $script:RuleSuspend = $true
    try {
        foreach ($k in $script:RuleTextMap.Keys) {
            $v = $M.($script:RuleTextMap[$k])
            $window.FindName($k).Text = if ($null -eq $v) { '' } else { "$v" }
        }
        $script:RuleCertBase64   = if ($M.CertBase64) { "$($M.CertBase64)" } else { $null }
        $script:RuleCertInfo     = "$($M.CertSubject)"
        $script:RuleReusableId   = if ($M.ReusableId) { "$($M.ReusableId)" } else { $null }
        $script:RuleReusableName = "$($M.ReusableName)"
        switch ("$($M.SigSource)") {
            'upload'   { $window.FindName('rbSigUpload').IsChecked = $true }
            'reusable' { $window.FindName('rbSigReusable').IsChecked = $true }
            default    { $window.FindName('rbSigNone').IsChecked = $true }
        }
        if ("$($M.CertType)" -eq 'ca') { $window.FindName('rbCertCA').IsChecked = $true } else { $window.FindName('rbCertPublisher').IsChecked = $true }
        switch ("$($M.ElevationType)") {
            'automatic'   { $window.FindName('rbElAuto').IsChecked = $true }
            'support'     { $window.FindName('rbElSupport').IsChecked = $true }
            'currentuser' { $window.FindName('rbElCurrent').IsChecked = $true }
            'deny'        { $window.FindName('rbElDeny').IsChecked = $true }
            default       { $window.FindName('rbElUser').IsChecked = $true }
        }
        $window.FindName('chkValJustification').IsChecked = [bool]$M.ValJustification
        $window.FindName('chkValWinAuth').IsChecked       = [bool]$M.ValWinAuth
        switch ("$($M.ChildProcess)") {
            'allow' { $window.FindName('rbChildAllow').IsChecked = $true }
            'deny'  { $window.FindName('rbChildDeny').IsChecked = $true }
            default { $window.FindName('rbChildRule').IsChecked = $true }
        }
        $window.FindName('txtCertFile').Text = if ($script:RuleCertBase64) { '(certificate loaded)' } else { '(no certificate)' }
    } finally { $script:RuleSuspend = $false }
    & $script:RuleRefresh
}

$script:RuleDefaultModel = {
    [ordered]@{ Name=''; Description=''; FileName=''; FilePath=''; FileHash=''; MinVersion=''; ProductName='';
                InternalName=''; FileDescription=''; SigSource='none'; CertBase64=$null; CertSubject=''; CertType='publisher';
                ReusableId=$null; ReusableName=''; ElevationType='self'; ValJustification=$true; ValWinAuth=$false; ChildProcess='rule' }
}

$script:RuleResetAll = {
    $script:RuleAttrs = @(); $script:RuleAttrsApplied = $false
    $script:RuleCerts = @{}; $script:RuleExePath = $null
    $window.FindName('attrList').Children.Clear()
    $window.FindName('lblAttrHeader').Visibility = 'Collapsed'
    $window.FindName('lblSourceInfo').Text = 'No source selected yet.'
    $window.FindName('panelPushResult').Visibility = 'Collapsed'
    $window.FindName('btnNewRule').Visibility = 'Collapsed'
    & $script:RuleWriteForm (& $script:RuleDefaultModel)
}

# ---- Visibility & live preview ------------------------------
$script:RuleUpdateVisibility = {
    $sigUpload   = [bool]$window.FindName('rbSigUpload').IsChecked
    $sigReusable = [bool]$window.FindName('rbSigReusable').IsChecked
    $window.FindName('panelSigUpload').Visibility   = if ($sigUpload)   { 'Visible' } else { 'Collapsed' }
    $window.FindName('panelSigReusable').Visibility = if ($sigReusable) { 'Visible' } else { 'Collapsed' }
    $window.FindName('panelCertType').Visibility    = if ($sigUpload -or $sigReusable) { 'Visible' } else { 'Collapsed' }

    $just = $window.FindName('chkValJustification'); $auth = $window.FindName('chkValWinAuth')
    $help = $window.FindName('lblElHelp')
    if ($window.FindName('rbElAuto').IsChecked) {
        $help.Text = 'Elevates silently, without a prompt. Use only for trusted, signed tools.'
        $window.FindName('panelValidation').Visibility = 'Collapsed'
    } elseif ($window.FindName('rbElSupport').IsChecked) {
        $help.Text = 'The user submits a request; an admin approves it in Intune before it can run elevated.'
        $window.FindName('panelValidation').Visibility = 'Collapsed'
    } elseif ($window.FindName('rbElCurrent').IsChecked) {
        $help.Text = 'Runs elevated under the signed-in user''s own profile instead of a virtual account. Windows authentication is required.'
        $window.FindName('panelValidation').Visibility = 'Visible'
        $just.IsChecked = $false; $just.IsEnabled = $false
        $auth.IsChecked = $true;  $auth.IsEnabled = $false
    } elseif ($window.FindName('rbElDeny').IsChecked) {
        $help.Text = 'Blocks this file from running elevated.'
        $window.FindName('panelValidation').Visibility = 'Collapsed'
    } else {
        $help.Text = 'The user sees a prompt and confirms before the app runs elevated. Optional extra checks:'
        $window.FindName('panelValidation').Visibility = 'Visible'
        $just.IsEnabled = $true; $auth.IsEnabled = $true
    }
    $window.FindName('panelChildProc').Visibility = if ($window.FindName('rbElDeny').IsChecked) { 'Collapsed' } else { 'Visible' }
    $window.FindName('lblCertInfo').Text = if ($script:RuleCertInfo) { $script:RuleCertInfo } elseif ($script:RuleCertBase64) { '(certificate loaded)' } else { 'No certificate loaded.' }
}

$script:RuleCurrentSchema = {
    if ($script:EpmRulesTemplate -and $script:EpmSchemaCache.ContainsKey("$($script:EpmRulesTemplate.id)")) {
        return $script:EpmSchemaCache["$($script:EpmRulesTemplate.id)"]
    }
    return $script:EpmEmptySchema
}

$script:RuleRefresh = {
    if ($script:RuleSuspend) { return }
    $script:RuleSuspend = $true
    try { & $script:RuleUpdateVisibility } finally { $script:RuleSuspend = $false }

    $m = & $script:RuleReadForm

    # Preview (certificate shortened so the JSON stays readable)
    $pm = [ordered]@{}; foreach ($k in $m.Keys) { $pm[$k] = $m[$k] }
    if ($pm.CertBase64 -and $pm.CertBase64.Length -gt 40) { $pm.CertBase64 = $pm.CertBase64.Substring(0, 24) + "…($($m.CertBase64.Length) chars)" }
    $script:EpmQuiet = $true
    try {
        $val = & $script:EpmBuildRuleValue (& $script:RuleCurrentSchema) $pm $false
        $window.FindName('txtRulePreview').Text = (ConvertTo-Json -InputObject $val -Depth 64).Replace("$($script:EpmRoot)_", '…_')
    } catch {
        $window.FindName('txtRulePreview').Text = "Preview error: $($_.Exception.Message)"
    } finally { $script:EpmQuiet = $false }

    # Strength meter
    $st = & $script:RuleStrength $m
    $on = switch ($st.Bars) { 1 { '#C1554A' } 2 { '#D9A441' } default { '#5FA88A' } }
    for ($i = 1; $i -le 4; $i++) {
        $window.FindName("strBar$i").Background = & $script:BrushOf $(if ($i -le $st.Bars) { $on } else { '#3A3B40' })
    }
    $window.FindName('lblStrength').Text     = $st.Label
    $window.FindName('lblStrengthTips').Text = ($st.Tips | ForEach-Object { "• $_" }) -join "`n"

    $v = & $script:RuleValidate $m
    $lines = @($v.Errors | ForEach-Object { "✖ $_" }) + @($v.Warnings | ForEach-Object { "⚠ $_" })
    $window.FindName('lblRuleIssues').Text = $lines -join "`n"
}

# ---- Wizard navigation --------------------------------------
$script:RuleGoStep = {
    param([int]$Step)
    $script:RuleStep = $Step
    for ($i = 1; $i -le 4; $i++) {
        $window.FindName("ruleStep$i").Visibility = if ($i -eq $Step) { 'Visible' } else { 'Collapsed' }
        $badge = $window.FindName("stepBadge$i"); $num = $window.FindName("stepNum$i"); $txt = $window.FindName("stepText$i")
        if ($i -lt $Step) {
            $badge.Background = & $script:BrushOf '#2A3B33'; $badge.BorderBrush = & $script:BrushOf '#2A3B33'
            $num.Text = '✓'; $num.Foreground = & $script:BrushOf '#5FA88A'
            $txt.Foreground = & $script:BrushOf '#A3A29E'; $txt.FontWeight = 'Normal'
        } elseif ($i -eq $Step) {
            $badge.Background = & $script:BrushOf '#C97B3D'; $badge.BorderBrush = & $script:BrushOf '#C97B3D'
            $num.Text = "$i"; $num.Foreground = & $script:BrushOf '#FFFFFF'
            $txt.Foreground = & $script:BrushOf '#E8E6E1'; $txt.FontWeight = 'SemiBold'
        } else {
            $badge.Background = & $script:BrushOf '#00000000'; $badge.BorderBrush = & $script:BrushOf '#4A4B50'
            $num.Text = "$i"; $num.Foreground = & $script:BrushOf '#8C8B86'
            $txt.Foreground = & $script:BrushOf '#8C8B86'; $txt.FontWeight = 'Normal'
        }
    }
    $window.FindName('btnRuleBack').IsEnabled = ($Step -gt 1)
    $next = $window.FindName('btnRuleNext')
    $next.Visibility = if ($Step -lt 4) { 'Visible' } else { 'Collapsed' }
    $next.Content = switch ($Step) { 1 { 'Next: Rule details →' } 2 { 'Next: Target policy →' } default { 'Next: Review →' } }

    if ($Step -eq 3 -and $script:GraphToken -and @($script:EpmPolicies).Count -eq 0) { & $script:RuleLoadPolicies }
    if ($Step -eq 3 -and -not $script:GraphToken) { & $script:WriteLog "Connect to Graph (top of this page) to list your elevation rules policies." "WARN" }
    if ($Step -eq 4) { & $script:RuleBuildSummary }
}

# ---- Sources ------------------------------------------------
$script:RuleAttrsFromExe = {
    param([string]$Path)
    $vi   = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
    $ver  = '{0}.{1}.{2}.{3}' -f $vi.FileMajorPart, $vi.FileMinorPart, $vi.FileBuildPart, $vi.FilePrivatePart
    if ($ver -eq '0.0.0.0') { $ver = '' }
    $pub = $null; $ca = $null
    $sig = Get-AuthenticodeSignature -LiteralPath $Path
    if ($sig.SignerCertificate) {
        $pub = $sig.SignerCertificate
        try {
            $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
            $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
            [void]$chain.Build($pub)
            if ($chain.ChainElements.Count -gt 1) { $ca = $chain.ChainElements[1].Certificate }
        } catch {}
    }
    if ("$($sig.Status)" -ne 'Valid') { & $script:WriteLog "Signature status of $([IO.Path]::GetFileName($Path)): $($sig.Status)" "WARN" }
    $script:RuleCerts   = @{ publisher = $pub; ca = $ca }
    $script:RuleExePath = $Path
    @(
        [pscustomobject]@{ Key = 'filename';        Label = 'File name';      Value = [IO.Path]::GetFileName($Path);      On = $true }
        [pscustomobject]@{ Key = 'filepath';        Label = 'File path';      Value = [IO.Path]::GetDirectoryName($Path); On = $true }
        [pscustomobject]@{ Key = 'filehash';        Label = 'SHA-256';        Value = $hash;                              On = $true }
        [pscustomobject]@{ Key = 'pubcert';         Label = 'Publisher cert'; Value = (& $script:CertSummary $pub);       On = [bool]$pub }
        [pscustomobject]@{ Key = 'cacert';          Label = 'CA cert';        Value = (& $script:CertSummary $ca);        On = $false }
        [pscustomobject]@{ Key = 'minversion';      Label = 'Minimum version'; Value = $ver;                              On = [bool]$ver }
        [pscustomobject]@{ Key = 'productname';     Label = 'Product name';   Value = "$($vi.ProductName)".Trim();        On = [bool]"$($vi.ProductName)".Trim() }
        [pscustomobject]@{ Key = 'internalname';    Label = 'Internal name';  Value = "$($vi.InternalName)".Trim();       On = $false }
        [pscustomobject]@{ Key = 'filedescription'; Label = 'File description'; Value = "$($vi.FileDescription)".Trim();  On = $false }
    ) | Where-Object { $_.Value }
}

$script:RuleAttrsFromEvent = {
    param($Ev)
    $fp  = "$($Ev.filePath)"
    $fn  = if ($fp) { ($fp -split '[\\/]')[-1] } else { '' }
    $dir = if ($fp) { $fp.Substring(0, $fp.Length - $fn.Length).TrimEnd('\', '/') } else { '' }
    $pub = $null
    if ($Ev.certificatePayload) {
        try { $pub = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(, [Convert]::FromBase64String("$($Ev.certificatePayload)")) }
        catch { & $script:WriteLog "The event's certificate payload couldn't be read as a certificate." "WARN" }
    }
    $ver = if ("$($Ev.fileVersion)" -match '^\d+(\.\d+){0,3}') { $Matches[0] } else { '' }
    $script:RuleCerts   = @{ publisher = $pub; ca = $null }
    $script:RuleExePath = $null
    @(
        [pscustomobject]@{ Key = 'filename';        Label = 'File name';      Value = $fn;  On = $true }
        # user-profile folders differ per user, so don't match on them by default
        [pscustomobject]@{ Key = 'filepath';        Label = 'File path';      Value = $dir; On = ($dir -notmatch '\\Users\\') }
        [pscustomobject]@{ Key = 'filehash';        Label = 'SHA-256';        Value = "$($Ev.hash)"; On = $true }
        [pscustomobject]@{ Key = 'pubcert';         Label = 'Publisher cert'; Value = (& $script:CertSummary $pub); On = [bool]$pub }
        [pscustomobject]@{ Key = 'minversion';      Label = 'Minimum version'; Value = $ver; On = [bool]$ver }
        [pscustomobject]@{ Key = 'productname';     Label = 'Product name';   Value = "$($Ev.productName)".Trim(); On = [bool]"$($Ev.productName)".Trim() }
        [pscustomobject]@{ Key = 'internalname';    Label = 'Internal name';  Value = "$($Ev.internalName)".Trim(); On = $false }
        [pscustomobject]@{ Key = 'filedescription'; Label = 'File description'; Value = "$($Ev.fileDescription)".Trim(); On = $false }
    ) | Where-Object { $_.Value }
}

$script:RuleShowAttrs = {
    param($Attrs, [string]$Info)
    $script:RuleAttrs = @($Attrs); $script:RuleAttrsApplied = $false
    $list = $window.FindName('attrList'); $list.Children.Clear()
    $window.FindName('lblSourceInfo').Text = $Info
    $window.FindName('lblAttrHeader').Visibility = if ($script:RuleAttrs.Count) { 'Visible' } else { 'Collapsed' }
    foreach ($a in $script:RuleAttrs) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Style     = $window.FindResource('DarkCheck')
        $cb.Tag       = $a.Key
        $cb.IsChecked = [bool]$a.On
        $cb.Margin    = New-Object System.Windows.Thickness(0, 0, 0, 8)
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.TextWrapping = 'Wrap'
        $r1 = New-Object System.Windows.Documents.Run("$($a.Label):  ")
        $r1.Foreground = & $script:BrushOf '#A3A29E'
        $r2 = New-Object System.Windows.Documents.Run("$($a.Value)")
        $r2.FontFamily = 'Consolas'
        $tb.Inlines.Add($r1); $tb.Inlines.Add($r2)
        $cb.Content = $tb
        if ($a.Key -in @('pubcert','cacert')) {
            # a rule uses one certificate: publisher OR certificate authority
            $cb.Add_Checked({
                $other = if ("$($this.Tag)" -eq 'pubcert') { 'cacert' } else { 'pubcert' }
                foreach ($c in $window.FindName('attrList').Children) { if ("$($c.Tag)" -eq $other) { $c.IsChecked = $false } }
            })
        }
        [void]$list.Children.Add($cb)
    }
}

$script:RuleApplyAttrs = {
    $boxes = @($window.FindName('attrList').Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] })
    if ($boxes.Count -eq 0 -or $script:RuleAttrsApplied) { return }
    $m   = & $script:RuleReadForm
    $sel = @{}; foreach ($b in $boxes) { $sel["$($b.Tag)"] = [bool]$b.IsChecked }
    $raw = @{}; foreach ($a in $script:RuleAttrs) { $raw[$a.Key] = "$($a.Value)" }
    $map = @{ filename='FileName'; filepath='FilePath'; filehash='FileHash'; minversion='MinVersion';
              productname='ProductName'; internalname='InternalName'; filedescription='FileDescription' }
    foreach ($k in $map.Keys) { if ($raw.ContainsKey($k)) { $m[$map[$k]] = if ($sel[$k]) { $raw[$k] } else { '' } } }

    $cert = $null; $type = 'publisher'
    if ($sel['pubcert'] -and $script:RuleCerts.publisher) { $cert = $script:RuleCerts.publisher }
    elseif ($sel['cacert'] -and $script:RuleCerts.ca)     { $cert = $script:RuleCerts.ca; $type = 'ca' }
    if ($cert) {
        $m.SigSource   = 'upload'; $m.CertType = $type
        $m.CertBase64  = [Convert]::ToBase64String($cert.RawData)
        $m.CertSubject = & $script:CertSummary $cert
    } elseif ($sel.ContainsKey('pubcert') -or $sel.ContainsKey('cacert')) {
        $m.SigSource = 'none'; $m.CertBase64 = $null; $m.CertSubject = ''
    }
    if (-not $m.Name) { $m.Name = if ($m.ProductName) { "$($m.ProductName) – $($m.FileName)" } else { "$($m.FileName)" } }
    & $script:RuleWriteForm $m
    $script:RuleAttrsApplied = $true
}

$script:RuleLoadEvent = {
    param([string]$Id)
    $ev = $script:ElevationEventsRaw[$Id]
    if (-not $ev) { & $script:WriteLog "Elevation event $Id not found in the loaded events." "ERR"; return }
    $attrs = @(& $script:RuleAttrsFromEvent $ev)
    $info  = "Event: $($ev.filePath)`n$($ev.upn) on $($ev.deviceName) · $(& $script:FormatDate $ev.eventDateTime) · $($ev.elevationType)"
    & $script:RuleShowAttrs $attrs $info
    & $script:WriteLog "Rule source: elevation event for $($ev.filePath)." "OK"
}

# Modal picker for elevation events (own window, styles inline)
$script:ShowEventPicker = {
    [xml]$px = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Pick an elevation event" Height="580" Width="1100" MinHeight="300" MinWidth="600"
        WindowStartupLocation="CenterOwner"
        Background="#17181C" Foreground="#E8E6E1" FontFamily="Segoe UI">
    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox x:Name="pf" Background="#26272B" Foreground="#E8E6E1" CaretBrush="#C97B3D"
                     BorderBrush="#35363B" BorderThickness="1" Padding="8,7" FontSize="12"
                     ToolTip="Type to filter across all columns"/>
            <CheckBox x:Name="pUnmanaged" Grid.Column="1" Content="Only events without a rule (unmanaged)"
                      Foreground="#E8E6E1" FontSize="12" Margin="12,0,0,0" VerticalAlignment="Center"/>
        </Grid>
        <DataGrid x:Name="pg" Grid.Row="1"
                  Background="#1F2023" Foreground="#E8E6E1" BorderBrush="#35363B" BorderThickness="1"
                  GridLinesVisibility="Horizontal" HorizontalGridLinesBrush="#35363B"
                  RowBackground="#1F2023" AlternatingRowBackground="#232428"
                  FontSize="12" AutoGenerateColumns="True" IsReadOnly="True"
                  SelectionMode="Single" HeadersVisibility="Column" CanUserResizeRows="False">
            <DataGrid.ColumnHeaderStyle>
                <Style TargetType="DataGridColumnHeader">
                    <Setter Property="Background" Value="#26272B"/>
                    <Setter Property="Foreground" Value="#A3A29E"/>
                    <Setter Property="Padding" Value="10,6"/>
                    <Setter Property="FontWeight" Value="SemiBold"/>
                    <Setter Property="BorderBrush" Value="#35363B"/>
                    <Setter Property="BorderThickness" Value="0,0,0,1"/>
                </Style>
            </DataGrid.ColumnHeaderStyle>
            <DataGrid.CellStyle>
                <Style TargetType="DataGridCell">
                    <Setter Property="BorderThickness" Value="0"/>
                    <Setter Property="Padding" Value="10,5"/>
                    <Style.Triggers>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter Property="Background" Value="#3A2A1C"/>
                            <Setter Property="Foreground" Value="#F0C08A"/>
                        </Trigger>
                    </Style.Triggers>
                </Style>
            </DataGrid.CellStyle>
        </DataGrid>
        <Grid Grid.Row="2" Margin="0,10,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="pStatus" Foreground="#A3A29E" FontSize="11" FontFamily="Consolas" VerticalAlignment="Center"/>
            <Button x:Name="pOk" Grid.Column="1" Content="Use this event" Background="#C97B3D" Foreground="White"
                    BorderThickness="0" Padding="16,8" Margin="0,0,8,0" FontWeight="SemiBold" Cursor="Hand"/>
            <Button x:Name="pCancel" Grid.Column="2" Content="Cancel" Background="#35363B" Foreground="White"
                    BorderThickness="0" Padding="16,8" Cursor="Hand"/>
        </Grid>
    </Grid>
</Window>
'@
    $pw = [System.Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($px))
    $pw.Owner = $window
    $rows = @($script:ElevationEvents | ForEach-Object {
        [pscustomobject]@{
            Time = & $script:FormatDate $_.EventDateTime; File = $_.FilePath; Publisher = $_.Publisher
            Type = $_.ElevationType; Result = $_.Result; User = $_.UPN; Device = $_.DeviceName; Id = $_.Id
        } })
    $dt = & $script:ToDataTable $rows @('Time','File','Publisher','Type','Result','User','Device','Id')
    $pg = $pw.FindName('pg'); $pf = $pw.FindName('pf'); $pu = $pw.FindName('pUnmanaged'); $ps = $pw.FindName('pStatus')
    $pg.Add_AutoGeneratingColumn({ param($s, $e) if ($e.PropertyName -eq 'Id') { $e.Column.Visibility = 'Collapsed' } })
    $pg.ItemsSource = $dt.DefaultView
    $ps.Text = "$($dt.Rows.Count) event(s)"
    # GetNewClosure() gives handlers their own $script: scope, so return the pick via a captured hashtable
    $pick = @{ Id = $null }

    $applyFilter = {
        $f = ($pf.Text.Trim() -replace "[\[\]\*%]", '').Replace("'", "''")
        $parts = @()
        if ($f) { $parts += '(' + ((@('Time','File','Publisher','Type','Result','User','Device') | ForEach-Object { "[$_] LIKE '%$f%'" }) -join ' OR ') + ')' }
        if ($pu.IsChecked) { $parts += "[Type] LIKE '%unmanaged%'" }
        try { $dt.DefaultView.RowFilter = ($parts -join ' AND ') } catch { $dt.DefaultView.RowFilter = '' }
        $ps.Text = "$($dt.DefaultView.Count) of $($dt.Rows.Count) event(s)"
    }.GetNewClosure()
    $pf.Add_TextChanged($applyFilter)
    $pu.Add_Checked($applyFilter); $pu.Add_Unchecked($applyFilter)

    $accept = {
        if ($pg.SelectedItem) { $pick.Id = "$($pg.SelectedItem.Row['Id'])"; $pw.Close() }
        else { $ps.Text = 'Select an event first.' }
    }.GetNewClosure()
    $pw.FindName('pOk').Add_Click($accept)
    $pg.Add_MouseDoubleClick($accept)
    $pw.FindName('pCancel').Add_Click({ $pw.Close() }.GetNewClosure())
    [void]$pw.ShowDialog()
    return $pick.Id
}

# ---- Target policy ------------------------------------------
$script:RuleFillPolicyGrids = {
    $rows = @($script:EpmPolicies | ForEach-Object {
        [pscustomobject]@{ Name = $_.name; Modified = (& $script:FormatDate $_.lastModifiedDateTime); Description = $_.description; Id = $_.id }
    })
    foreach ($g in 'gridPolicies','gridRulePolicies') {
        $dt = & $script:ToDataTable $rows @('Name','Modified','Description','Id')
        $window.FindName($g).ItemsSource = $dt.DefaultView
    }
    & $script:RuleFilterPolicies
}

$script:RuleFilterPolicies = {
    $view = $window.FindName('gridPolicies').ItemsSource
    if (-not $view) { return }
    $f = ($window.FindName('txtPolicyFilter').Text.Trim() -replace "[\[\]\*%]", '').Replace("'", "''")
    try { $view.RowFilter = if ($f) { "[Name] LIKE '%$f%' OR [Description] LIKE '%$f%'" } else { '' } } catch { $view.RowFilter = '' }
}

$script:RuleLoadPolicies = {
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        & $script:WriteLog "Loading elevation rules policies from Intune..."
        $script:EpmPolicies = @(& $script:EpmGetRulePolicies)
        & $script:RuleFillPolicyGrids
        & $script:WriteLog "$($script:EpmPolicies.Count) elevation rules polic(ies) found." "OK"
    } catch {
        & $script:WriteLog "Couldn't load policies: $($_.Exception.Message)" "ERR"
    } finally { $window.Cursor = [System.Windows.Input.Cursors]::Arrow }
}

$script:RuleInspectPolicy = {
    param([string]$Id)
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        $full  = & $script:EpmGetPolicyFull $Id
        $script:SelectedPolicyFull = $full
        $rules = @(& $script:EpmParseRules $full.Settings)
        $targets = @()
        try {
            foreach ($a in @(& $script:GraphGetAll "/deviceManagement/configurationPolicies('$Id')/assignments")) {
                $t = "$($a.target.'@odata.type')"
                $targets += switch -Wildcard ($t) {
                    '*allLicensedUsers*' { 'All users' }
                    '*allDevices*'       { 'All devices' }
                    '*Group*' {
                        $gid = "$($a.target.groupId)"
                        $gn  = $gid
                        try { $gn = (& $script:InvokeGraph 'GET' "/groups/$($gid)?`$select=displayName").displayName } catch {}
                        if ($t -like '*exclusion*') { "excl. $gn" } else { $gn }
                    }
                    default { $t }
                }
            }
        } catch {}
        $assigned = if ($targets.Count) { $targets -join ', ' } else { 'not assigned' }
        $window.FindName('lblPolicyInfo').Text = "$($rules.Count) rule(s)  ·  assigned to: $assigned"

        $m    = & $script:RuleReadForm
        $dups = @($rules | Where-Object { $m.FileName -and "$($_.FileName)" -ieq "$($m.FileName)" })
        if ($dups.Count) {
            $list = ($dups | ForEach-Object { "'$($_.RuleName)' ($($_.ElevationType))" }) -join ', '
            $window.FindName('lblDuplicate').Text = "This policy already has $($dups.Count) rule(s) for $($m.FileName): $list"
            $window.FindName('panelDuplicate').Visibility = 'Visible'
        } else {
            $window.FindName('panelDuplicate').Visibility = 'Collapsed'
            $window.FindName('rbDupAdd').IsChecked = $true
        }
    } catch {
        & $script:WriteLog "Couldn't read policy: $($_.Exception.Message)" "ERR"
    } finally { $window.Cursor = [System.Windows.Input.Cursors]::Arrow }
}

$script:RuleReadTarget = {
    if ($window.FindName('rbTargetNew').IsChecked) {
        $name = $window.FindName('txtNewPolicyName').Text.Trim()
        if (-not $name) { return [pscustomobject]@{ Error = 'Enter a name for the new policy.' } }
        $assign = if ($window.FindName('rbAssignUsers').IsChecked) { 'users' } elseif ($window.FindName('rbAssignDevices').IsChecked) { 'devices' } elseif ($window.FindName('rbAssignGroup').IsChecked) { 'group' } else { 'none' }
        $gid = $null; $gname = $null
        if ($assign -eq 'group') {
            $sel = $window.FindName('gridGroups').SelectedItem
            if (-not $sel) { return [pscustomobject]@{ Error = 'Search and select a group to assign to.' } }
            $gid = "$($sel.Row['Id'])"; $gname = "$($sel.Row['Name'])"
        }
        return [pscustomobject]@{ Error = $null; Mode = 'new'; Name = $name; Description = $window.FindName('txtNewPolicyDesc').Text.Trim(); Assign = $assign; GroupId = $gid; GroupName = $gname }
    }
    $sel = $window.FindName('gridPolicies').SelectedItem
    if (-not $sel) { return [pscustomobject]@{ Error = 'Select the elevation rules policy to add the rule to.' } }
    $replace = ($window.FindName('panelDuplicate').Visibility -eq 'Visible') -and [bool]$window.FindName('rbDupReplace').IsChecked
    [pscustomobject]@{ Error = $null; Mode = 'existing'; PolicyId = "$($sel.Row['Id'])"; PolicyName = "$($sel.Row['Name'])"; Replace = $replace }
}

$script:RuleBuildSummary = {
    $m = & $script:RuleReadForm
    $t = & $script:RuleReadTarget
    $match = @("$($m.FileName)")
    if ($m.FilePath)    { $match += "in $($m.FilePath)" }
    if ($m.FileHash)    { $match += "hash $($m.FileHash.Substring(0, [Math]::Min(8, $m.FileHash.Length)))…" }
    if ($m.SigSource -eq 'upload')   { $match += $(if ($m.CertType -eq 'ca') { 'CA certificate' } else { 'publisher certificate' }) }
    if ($m.SigSource -eq 'reusable') { $match += "reusable cert '$($m.ReusableName)'" }
    if ($m.MinVersion)  { $match += ">= $($m.MinVersion)" }
    if ($m.ProductName) { $match += "product '$($m.ProductName)'" }
    $el = switch ($m.ElevationType) { 'automatic' { 'Automatic' } 'support' { 'Support approved' } 'currentuser' { 'Elevate as current user (Windows authentication)' } 'deny' { 'Deny' } default {
              $v = @(); if ($m.ValJustification) { $v += 'business justification' }; if ($m.ValWinAuth) { $v += 'Windows authentication' }
              if ($v.Count) { "User confirmed ($($v -join ' + '))" } else { 'User confirmed' } } }
    $cp = switch ($m.ChildProcess) { 'allow' { 'Allow all child processes to run elevated' } 'deny' { 'Deny all' } default { 'Require rule to elevate' } }
    if ($m.ElevationType -eq 'deny') { $cp = 'n/a' }

    $target = '—'; $calls = @()
    if ($t.Error) { $target = "⚠ $($t.Error)" }
    elseif ($t.Mode -eq 'existing') {
        $count = if ($script:SelectedPolicyFull) { @(& $script:EpmParseRules $script:SelectedPolicyFull.Settings).Count } else { $null }
        $target = "Existing policy '$($t.PolicyName)'"
        if ($null -ne $count) { $target += "  ($count rule(s) now)" }
        if ($t.Replace) { $target += "`n              replaces the existing rule(s) for $($m.FileName)" }
        $calls = @(
            "GET  /beta/deviceManagement/configurationPolicies('$($t.PolicyId)')",
            "GET  /beta/deviceManagement/configurationPolicies('$($t.PolicyId)')/settings",
            "PUT  /beta/deviceManagement/configurationPolicies('$($t.PolicyId)')   (full policy, rule appended)"
        )
    } else {
        $who = switch ($t.Assign) { 'users' { 'All users' } 'devices' { 'All devices' } 'group' { "group '$($t.GroupName)'" } default { 'not assigned yet' } }
        $target = "New policy '$($t.Name)', $who"
        $calls = @(
            "GET  /beta/deviceManagement/configurationPolicyTemplates   (Elevation rules policy template)",
            "POST /beta/deviceManagement/configurationPolicies"
        )
        if ($t.Assign -ne 'none') { $calls += "POST /beta/deviceManagement/configurationPolicies('{new id}')/assign" }
    }
    $window.FindName('txtSummary').Text = @(
        "Rule        : $($m.Name)",
        "Match       : $($match -join ' · ')",
        "Elevation   : $el",
        "Child procs : $cp",
        "Target      : $target"
    ) -join "`n"
    $window.FindName('txtGraphCalls').Text = $calls -join "`n"

    $scp = & $script:GetTokenScopes
    $lbl = $window.FindName('lblScopeStatus')
    if (-not $script:GraphToken) {
        $lbl.Text = '✖ Not connected. Click "Connect to Graph" at the top of this page.'; $lbl.Foreground = & $script:BrushOf '#E57A6E'
    } elseif ($scp -contains 'DeviceManagementConfiguration.ReadWrite.All') {
        $lbl.Text = "✓ Signed in as $($script:GraphAccount) with DeviceManagementConfiguration.ReadWrite.All"; $lbl.Foreground = & $script:BrushOf '#5FA88A'
    } else {
        $lbl.Text = '✖ The current sign-in lacks DeviceManagementConfiguration.ReadWrite.All. Click "Connect to Graph" at the top of this page to sign in again.'
        $lbl.Foreground = & $script:BrushOf '#E57A6E'
    }
    $window.FindName('panelPushResult').Visibility = 'Collapsed'
}

# ---- Push ---------------------------------------------------
$script:RuleSaveBackup = {
    param($Full)
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if (-not $docs) { $docs = if ($env:USERPROFILE) { Join-Path $env:USERPROFILE 'Documents' } else { [IO.Path]::GetTempPath() } }
    $dir = Join-Path $docs 'EpmTools\Backups'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $safe = ("$($Full.Policy.name)" -replace '[\\/:*?"<>|]', '_')
    $file = Join-Path $dir "$safe-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    ConvertTo-Json -InputObject ([ordered]@{ policy = $Full.Policy; settings = @($Full.Settings) }) -Depth 64 |
        Set-Content -LiteralPath $file -Encoding UTF8
    & $script:WriteLog "Backup saved: $file" "OK"
}

$script:RulePush = {
    param([bool]$DryRun)
    $m = & $script:RuleReadForm
    $v = & $script:RuleValidate $m
    if ($v.Errors.Count) { & $script:SetResult ("Fix these first:`n" + ($v.Errors -join "`n")) 'err'; return }
    $t = & $script:RuleReadTarget
    if ($t.Error) { & $script:SetResult $t.Error 'err'; return }
    if (-not $script:GraphToken) { & $script:SetResult 'Not connected to Microsoft Graph.' 'err'; return }

    if (-not $DryRun) {
        $scp = & $script:GetTokenScopes
        if ($scp.Count -gt 0 -and ($scp -notcontains 'DeviceManagementConfiguration.ReadWrite.All')) {
            & $script:SetResult 'Your sign-in lacks DeviceManagementConfiguration.ReadWrite.All. Use "Connect to Graph" on this page and sign in again.' 'err'
            return
        }
        $where = if ($t.Mode -eq 'existing') { "policy '$($t.PolicyName)'" } else { "a new policy '$($t.Name)'" }
        $ans = [System.Windows.MessageBox]::Show("Push rule '$($m.Name)' to $($where)?`n`nAssigned devices pick it up at their next Intune check-in.",
                   'Push to Intune', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($ans -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        if ($t.Mode -eq 'existing') {
            $full  = & $script:EpmGetPolicyFull $t.PolicyId
            $tplId = "$($full.Policy.templateReference.templateId)"
            $schema = & $script:EpmLoadSchema $tplId
            if (-not $schema.Loaded -and -not $DryRun) {
                $ans = [System.Windows.MessageBox]::Show("The EPM setting definitions couldn't be read, so built-in setting IDs will be used. Run a dry run first if unsure.`n`nContinue?",
                           'Setting definitions unavailable', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
                if ($ans -ne [System.Windows.MessageBoxResult]::Yes) { return }
            }
            $newVal   = & $script:EpmBuildRuleValue $schema $m $false
            $settings = @($full.Settings)
            $before   = @(& $script:EpmParseRules $settings).Count
            $removed  = 0
            $rootSetting = $settings | Where-Object { $_.settingInstance.settingDefinitionId -eq $script:EpmRoot } | Select-Object -First 1
            $outSettings = New-Object System.Collections.Generic.List[object]
            if ($rootSetting) {
                $vals = New-Object System.Collections.Generic.List[object]
                foreach ($gv in @($rootSetting.settingInstance.groupSettingCollectionValue)) {
                    if ($t.Replace) {
                        $f = @{}; & $script:EpmFlatten $gv.children $f
                        if ("$($f['filename'])" -ieq "$($m.FileName)") { $removed++; continue }
                    }
                    $vals.Add($gv)
                }
                $vals.Add($newVal)
                $rootSetting.settingInstance.groupSettingCollectionValue = $vals.ToArray()
            }
            foreach ($s in $settings) {
                $outSettings.Add([ordered]@{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'; settingInstance = $s.settingInstance })
            }
            if (-not $rootSetting) { $outSettings.Add((& $script:EpmBuildRootSetting $schema @($newVal) $false)) }
            $p = $full.Policy
            $body = [ordered]@{
                name              = $p.name
                description       = "$($p.description)"
                platforms         = $p.platforms
                technologies      = $p.technologies
                roleScopeTagIds   = @(if ($p.roleScopeTagIds) { $p.roleScopeTagIds } else { '0' })   # @() outside: an if-expression unrolls 1-item arrays
                templateReference = [ordered]@{ templateId = $tplId }
                settings          = $outSettings.ToArray()
            }
            $json  = ConvertTo-Json -InputObject $body -Depth 64
            $after = $before - $removed + 1
            $window.FindName('RawOutput').Text = $json
            if ($DryRun) {
                & $script:WriteLog "Dry run: PUT body for '$($p.name)' is in the Raw Output tab. Nothing was changed." "OK"
                & $script:SetResult "Dry run OK. The PUT request ($($json.Length) characters) is in the Raw Output tab. Policy would go from $before to $after rule(s). Nothing was changed." 'info'
                return
            }
            if ($window.FindName('chkBackup').IsChecked) { & $script:RuleSaveBackup $full }
            & $script:WriteLog "Updating policy '$($p.name)' ($before → $after rules)..." "INFO"
            [void](& $script:InvokeGraph 'PUT' "/deviceManagement/configurationPolicies('$($t.PolicyId)')" $json)
            $msg = "Rule '$($m.Name)' pushed to '$($p.name)' ($before → $after rules"
            if ($removed) { $msg += ", replaced $removed" }
            & $script:WriteLog "$msg)." "OK"
            & $script:SetResult "$msg). Devices pick it up at their next Intune check-in." 'ok'
        } else {
            $tpl    = & $script:EpmFindTemplate
            $schema = & $script:EpmLoadSchema "$($tpl.id)"
            $newVal = & $script:EpmBuildRuleValue $schema $m $true
            $body = [ordered]@{
                name              = $t.Name
                description       = $t.Description
                platforms         = 'windows10'
                technologies      = 'endpointPrivilegeManagement'
                roleScopeTagIds   = @('0')
                templateReference = [ordered]@{ templateId = "$($tpl.id)" }
                settings          = @( (& $script:EpmBuildRootSetting $schema @($newVal) $true) )
            }
            $json = ConvertTo-Json -InputObject $body -Depth 64
            $window.FindName('RawOutput').Text = $json
            if ($DryRun) {
                & $script:WriteLog "Dry run: POST body for new policy '$($t.Name)' is in the Raw Output tab. Nothing was changed." "OK"
                & $script:SetResult "Dry run OK. The POST request ($($json.Length) characters) is in the Raw Output tab. Nothing was changed." 'info'
                return
            }
            & $script:WriteLog "Creating policy '$($t.Name)'..." "INFO"
            $created = & $script:InvokeGraph 'POST' '/deviceManagement/configurationPolicies' $json
            $msg = "Policy '$($t.Name)' created with rule '$($m.Name)'"
            if ($t.Assign -ne 'none' -and $created.id) {
                $target = switch ($t.Assign) {
                    'users'   { [ordered]@{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' } }
                    'devices' { [ordered]@{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' } }
                    default   { [ordered]@{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $t.GroupId } }
                }
                $assignBody = [ordered]@{ assignments = @( [ordered]@{ target = $target } ) }
                try {
                    [void](& $script:InvokeGraph 'POST' "/deviceManagement/configurationPolicies('$($created.id)')/assign" $assignBody)
                    $msg += ' and assigned'
                } catch {
                    & $script:WriteLog "Policy created, but assigning it failed: $($_.Exception.Message)" "ERR"
                    $msg += ' (assignment FAILED, assign it in Intune)'
                }
            }
            $script:EpmPolicies = @()   # reload the list next time
            & $script:WriteLog "$msg." "OK"
            & $script:SetResult "$msg." 'ok'
        }
        $window.FindName('btnNewRule').Visibility = 'Visible'
        $script:SelectedPolicyFull = $null
    } catch {
        & $script:WriteLog "Push failed: $($_.Exception.Message)" "ERR"
        & $script:SetResult "Push failed:`n$($_.Exception.Message)" 'err'
    } finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
}

# ---- Wire up: Create Rule page ------------------------------
foreach ($gn in 'gridReusable','gridPolicies','gridGroups','gridRulePolicies') {
    $window.FindName($gn).Add_AutoGeneratingColumn({ param($s, $e) if ($e.PropertyName -eq 'Id') { $e.Column.Visibility = 'Collapsed' } })
}

foreach ($n in $script:RuleTextMap.Keys) { $window.FindName($n).Add_TextChanged({ & $script:RuleRefresh }) }
foreach ($n in 'rbSigNone','rbSigUpload','rbSigReusable','rbCertPublisher','rbCertCA',
               'rbElAuto','rbElUser','rbElSupport','rbElCurrent','rbElDeny',
               'rbChildRule','rbChildDeny','rbChildAllow') {
    $window.FindName($n).Add_Checked({ & $script:RuleRefresh })
}
foreach ($n in 'chkValJustification','chkValWinAuth') {
    $window.FindName($n).Add_Checked({ & $script:RuleRefresh })
    $window.FindName($n).Add_Unchecked({ & $script:RuleRefresh })
}

$window.FindName('btnSrcExe').Add_Click({
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.Title  = 'Select the file to build a rule for'
    $ofd.Filter = 'Executables (*.exe)|*.exe|All files (*.*)|*.*'
    if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        $attrs = @(& $script:RuleAttrsFromExe $ofd.FileName)
        $fi    = Get-Item -LiteralPath $ofd.FileName
        $sig   = if ($script:RuleCerts.publisher) { 'signed' } else { 'not signed' }
        & $script:RuleShowAttrs $attrs "$($ofd.FileName)`n$([Math]::Round($fi.Length / 1MB, 1)) MB · $sig"
        & $script:WriteLog "Rule source: $($ofd.FileName)" "OK"
    } catch {
        & $script:WriteLog "Couldn't read file: $($_.Exception.Message)" "ERR"
    } finally { $window.Cursor = [System.Windows.Input.Cursors]::Arrow }
})

$window.FindName('btnSrcEvent').Add_Click({
    if (@($script:ElevationEvents).Count -eq 0) {
        if (-not $script:GraphToken) {
            [void][System.Windows.MessageBox]::Show('Connect to Graph first (top of this page) to load elevation events.', 'Not connected')
            return
        }
        $window.Cursor = [System.Windows.Input.Cursors]::Wait
        try { $script:ElevationEvents = @(& $script:GetElevationEvents); & $script:WriteLog "$($script:ElevationEvents.Count) elevation event(s) loaded." "OK" }
        catch { & $script:WriteLog "Couldn't load elevation events: $($_.Exception.Message)" "ERR"; return }
        finally { $window.Cursor = [System.Windows.Input.Cursors]::Arrow }
        if (@($script:ElevationEvents).Count -eq 0) { & $script:WriteLog "No elevation events found." "WARN"; return }
    }
    $id = & $script:ShowEventPicker
    if ($id) { & $script:RuleLoadEvent $id }
})

$window.FindName('btnSrcDraft').Add_Click({
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.Filter = 'EpmTools rule draft (*.json)|*.json|All files (*.*)|*.*'
    if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    try {
        $d = Get-Content -LiteralPath $ofd.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
        $model = if ($d.rule) { $d.rule } else { $d }
        & $script:RuleResetAll
        & $script:RuleWriteForm $model
        $window.FindName('lblSourceInfo').Text = "Draft: $($ofd.FileName)"
        & $script:WriteLog "Draft loaded: $($ofd.FileName)" "OK"
        & $script:RuleGoStep 2
    } catch { & $script:WriteLog "Couldn't open draft: $($_.Exception.Message)" "ERR" }
})

$window.FindName('btnSrcBlank').Add_Click({
    & $script:RuleResetAll
    $window.FindName('lblSourceInfo').Text = 'Blank rule.'
    & $script:RuleGoStep 2
})

$window.FindName('btnRuleSaveDraft').Add_Click({
    $sfd = [System.Windows.Forms.SaveFileDialog]::new()
    $sfd.Filter = 'EpmTools rule draft (*.json)|*.json'
    $m = & $script:RuleReadForm
    $base = if ($m.FileName) { [IO.Path]::GetFileNameWithoutExtension($m.FileName) } else { 'rule' }
    $sfd.FileName = "EpmRule-$base-$(Get-Date -Format 'yyyyMMdd-HHmm').json"
    if ($sfd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    ConvertTo-Json -InputObject ([ordered]@{ epmToolsDraft = 1; saved = (Get-Date).ToString('s'); rule = $m }) -Depth 10 |
        Set-Content -LiteralPath $sfd.FileName -Encoding UTF8
    & $script:WriteLog "Draft saved: $($sfd.FileName)" "OK"
})

$window.FindName('btnHashFromFile').Add_Click({
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.Filter = 'Executables (*.exe)|*.exe|All files (*.*)|*.*'
    if ($script:RuleExePath) { $ofd.FileName = $script:RuleExePath }
    if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $window.FindName('txtFileHash').Text = (Get-FileHash -Algorithm SHA256 -LiteralPath $ofd.FileName).Hash
})

$window.FindName('btnBrowseCert').Add_Click({
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.Filter = 'Certificates (*.cer;*.crt;*.der;*.pem)|*.cer;*.crt;*.der;*.pem|All files (*.*)|*.*'
    if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    try {
        $c = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ofd.FileName)
        $script:RuleCertBase64 = [Convert]::ToBase64String($c.RawData)
        $script:RuleCertInfo   = & $script:CertSummary $c
        $window.FindName('txtCertFile').Text = $ofd.FileName
        $window.FindName('rbSigUpload').IsChecked = $true
        & $script:RuleRefresh
    } catch { & $script:WriteLog "Couldn't read certificate: $($_.Exception.Message)" "ERR" }
})

$window.FindName('btnLoadReusable').Add_Click({
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        $items = @(& $script:GraphGetAll "/deviceManagement/reusablePolicySettings?`$select=id,displayName,description,settingDefinitionId,lastModifiedDateTime" |
                   Where-Object { "$($_.settingDefinitionId)" -like '*privilegemanagement*' })
        $rows = @($items | ForEach-Object { [pscustomobject]@{ Name = $_.displayName; Description = $_.description; Modified = (& $script:FormatDate $_.lastModifiedDateTime); Id = $_.id } })
        $dt = & $script:ToDataTable $rows @('Name','Description','Modified','Id')
        $window.FindName('gridReusable').ItemsSource = $dt.DefaultView
        & $script:WriteLog "$($rows.Count) reusable EPM certificate(s) found." "OK"
    } catch { & $script:WriteLog "Couldn't load reusable settings: $($_.Exception.Message)" "ERR" }
    finally { $window.Cursor = [System.Windows.Input.Cursors]::Arrow }
})

$window.FindName('gridReusable').Add_SelectionChanged({
    $sel = $this.SelectedItem
    if ($sel) { $script:RuleReusableId = "$($sel.Row['Id'])"; $script:RuleReusableName = "$($sel.Row['Name'])"; & $script:RuleRefresh }
})

$window.FindName('btnRuleBack').Add_Click({ if ($script:RuleStep -gt 1) { & $script:RuleGoStep ($script:RuleStep - 1) } })

$window.FindName('btnRuleNext').Add_Click({
    switch ($script:RuleStep) {
        1 {
            & $script:RuleApplyAttrs
            & $script:RuleGoStep 2
        }
        2 {
            $v = & $script:RuleValidate (& $script:RuleReadForm)
            if ($v.Errors.Count) {
                [void][System.Windows.MessageBox]::Show(($v.Errors -join "`n"), 'Rule incomplete', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return
            }
            # Warm up the setting definitions so the preview uses the tenant's IDs
            if ($script:GraphToken -and -not $script:EpmRulesTemplate) {
                try { $tpl = & $script:EpmFindTemplate; [void](& $script:EpmLoadSchema "$($tpl.id)"); & $script:RuleRefresh }
                catch { & $script:WriteLog "Couldn't read the EPM template yet: $($_.Exception.Message)" "WARN" }
            }
            & $script:RuleGoStep 3
        }
        3 {
            $t = & $script:RuleReadTarget
            if ($t.Error) { [void][System.Windows.MessageBox]::Show($t.Error, 'Target policy'); return }
            & $script:RuleGoStep 4
        }
    }
})

$window.FindName('rbTargetExisting').Add_Checked({
    $window.FindName('panelTargetExisting').Visibility = 'Visible'; $window.FindName('panelTargetNew').Visibility = 'Collapsed'
})
$window.FindName('rbTargetNew').Add_Checked({
    $window.FindName('panelTargetExisting').Visibility = 'Collapsed'; $window.FindName('panelTargetNew').Visibility = 'Visible'
    $tb = $window.FindName('txtNewPolicyName')
    if (-not $tb.Text) { $m = & $script:RuleReadForm; $tb.Text = if ($m.ProductName) { "EPM – $($m.ProductName)" } else { 'EPM – Elevation rules' } }
})
foreach ($n in 'rbAssignNone','rbAssignUsers','rbAssignDevices','rbAssignGroup') {
    $window.FindName($n).Add_Checked({
        $window.FindName('panelGroupSearch').Visibility = if ($window.FindName('rbAssignGroup').IsChecked) { 'Visible' } else { 'Collapsed' }
    })
}

$window.FindName('btnRefreshPolicies').Add_Click({ & $script:RuleLoadPolicies })
$window.FindName('txtPolicyFilter').Add_TextChanged({ & $script:RuleFilterPolicies })
$window.FindName('gridPolicies').Add_SelectionChanged({
    $sel = $this.SelectedItem
    if ($sel) { & $script:RuleInspectPolicy "$($sel.Row['Id'])" }
})

$window.FindName('btnGroupSearch').Add_Click({
    $q = $window.FindName('txtGroupSearch').Text.Trim()
    if (-not $q) { return }
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        $f = [System.Uri]::EscapeDataString($q.Replace("'", "''"))
        $items = @(& $script:InvokeGraph 'GET' "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName,'$f')&`$select=id,displayName,description&`$top=50").value
        $rows = @($items | ForEach-Object { [pscustomobject]@{ Name = $_.displayName; Description = $_.description; Id = $_.id } })
        $window.FindName('gridGroups').ItemsSource = (& $script:ToDataTable $rows @('Name','Description','Id')).DefaultView
        & $script:WriteLog "$($rows.Count) group(s) found for '$q'." "OK"
    } catch { & $script:WriteLog "Group search failed: $($_.Exception.Message)" "ERR" }
    finally { $window.Cursor = [System.Windows.Input.Cursors]::Arrow }
})

$window.FindName('btnDryRun').Add_Click({ & $script:RulePush $true })
$window.FindName('btnPushRule').Add_Click({ & $script:RulePush $false })
$window.FindName('btnNewRule').Add_Click({ & $script:RuleResetAll; & $script:RuleGoStep 1 })

# ---- Wire up: Rule Policies page ----------------------------
$window.FindName('btnLoadRulePolicies').Add_Click({ & $script:RuleLoadPolicies })

$window.FindName('btnShowPolicyRules').Add_Click({
    $sel = $window.FindName('gridRulePolicies').SelectedItem
    if (-not $sel) { & $script:WriteLog "Select a policy first." "WARN"; return }
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        $full  = & $script:EpmGetPolicyFull "$($sel.Row['Id'])"
        $rules = @(& $script:EpmParseRules $full.Settings)
        & $script:WriteLog "Policy '$($sel.Row['Name'])': $($rules.Count) rule(s)." "OK"
        $window.FindName('RawOutput').Text = ConvertTo-Json -InputObject ([ordered]@{ policy = $full.Policy; settings = @($full.Settings) }) -Depth 64
        & $script:PopulateGrid $rules
    } catch { & $script:WriteLog "Couldn't read policy: $($_.Exception.Message)" "ERR" }
    finally { $window.Cursor = [System.Windows.Input.Cursors]::Arrow }
})

$window.FindName('btnExportPolicyJson').Add_Click({
    $sel = $window.FindName('gridRulePolicies').SelectedItem
    if (-not $sel) { & $script:WriteLog "Select a policy first." "WARN"; return }
    try {
        $full = & $script:EpmGetPolicyFull "$($sel.Row['Id'])"
        $sfd  = [System.Windows.Forms.SaveFileDialog]::new()
        $sfd.Filter   = 'JSON (*.json)|*.json'
        $sfd.FileName = ("$($sel.Row['Name'])" -replace '[\\/:*?"<>|]', '_') + '.json'
        if ($sfd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        ConvertTo-Json -InputObject ([ordered]@{ policy = $full.Policy; settings = @($full.Settings) }) -Depth 64 |
            Set-Content -LiteralPath $sfd.FileName -Encoding UTF8
        & $script:WriteLog "Policy exported to: $($sfd.FileName)" "OK"
    } catch { & $script:WriteLog "Export failed: $($_.Exception.Message)" "ERR" }
})

# ---- "Create rule from selection" in the report window ------
$timer.Add_Tick({
    $id = $script:Sync.PendingEventId
    if (-not $id) { return }
    $script:Sync.PendingEventId = $null
    try {
        $window.FindName('navCreateRule').IsChecked = $true
        & $script:RuleLoadEvent $id
        & $script:RuleGoStep 1
        [void]$window.Activate()
    } catch { & $script:WriteLog "Couldn't open the event in Create Rule: $($_.Exception.Message)" "ERR" }
})

# Initial state of the wizard
& $script:RuleGoStep 1
& $script:RuleRefresh


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
