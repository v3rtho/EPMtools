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
                <RowDefinition Height="*"/>
                <RowDefinition Height="400"/>
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

                </Grid>
            </ScrollViewer>

            <!-- ── OUTPUT / RESULTS PANE ── -->
            <Grid Grid.Row="2" Background="#17181C">
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
        'panelClientSettings','panelFileAttributes','panelReports'
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
        foreach ($obj in $allOutput) {
            if ($obj -is [System.Management.Automation.VerboseRecord]) {
                $msg = $obj.Message
                if ($msg -match 'Publisher Cert\?\s*\[True\]') {
                    $certName = if ($msg -match 'Name:\s*\[(?<n>[^\]]+)\]') { $Matches['n'] } else { 'Unknown' }
                    & $script:WriteLog "PUBLISHER CERTIFICATE FOUND: $certName" "CERT"
                } else {
                    & $script:WriteLog "VERBOSE: $msg" "INFO"
                }
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
# Reports — Microsoft Graph / EPM Elevation Events
# (No external module required — pure OAuth2 PKCE via browser)
# -------------------------------------------------------------
$window.FindName('btnConnectGraph').Add_Click({
    $tenantInput        = $window.FindName('txtTenantId').Text.Trim()
    $script:GraphTenant = if ($tenantInput) { $tenantInput } else { 'common' }
    $lblStatus          = $window.FindName('lblGraphStatus')

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
    $eScope  = [System.Uri]::EscapeDataString($script:GraphScope)
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
        scope       = $script:GraphScope
        redirectUri = $script:GraphRedirect
        verifier    = $verifier
    })
    $script:AuthPs     = $ps
    $script:AuthHandle = $ps.BeginInvoke()

    # Open the default browser to the Microsoft login page
    Start-Process $authUrl
    $lblStatus.Text       = "Browser opened — sign in and return here."
    $lblStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D9A441')
    $window.FindName('btnConnectGraph').IsEnabled = $false
    & $script:WriteLog "Browser opened for Microsoft account sign-in." "INFO"

    # DispatcherTimer polls every 500 ms until the background runspace completes
    $t = [System.Windows.Threading.DispatcherTimer]::new()
    $t.Interval = [TimeSpan]::FromMilliseconds(500)
    $t.Add_Tick({
        if (-not $script:AuthPs) { $script:AuthTimer.Stop(); $script:AuthTimer = $null; return }
        $state = $script:AuthPs.InvocationStateInfo.State
        if ($state -notin @('Running','NotStarted')) {
            $script:AuthTimer.Stop()
            $script:AuthTimer = $null
            $window.FindName('btnConnectGraph').IsEnabled = $true
            try {
                $res = $script:AuthPs.EndInvoke($script:AuthHandle) | Select-Object -Last 1
                if ($res -and $res.Success) {
                    $script:GraphToken   = $res.Token
                    $script:GraphRefresh = $res.Refresh
                    $script:GraphExpiry  = (Get-Date).AddSeconds($res.ExpiresIn - 60)
                    $window.FindName('lblGraphStatus').Text       = "Connected as: $($res.Account)"
                    $window.FindName('lblGraphStatus').Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#5FA88A')
                    $window.FindName('btnLoadElevationReport').IsEnabled = $true
                    & $script:WriteLog "Signed in as $($res.Account). Token valid until $($script:GraphExpiry.ToString('HH:mm:ss'))." "OK"
                } else {
                    $window.FindName('lblGraphStatus').Text       = "Sign-in failed: $($res.Error)"
                    $window.FindName('lblGraphStatus').Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#C1554A')
                    & $script:WriteLog "Graph sign-in failed: $($res.Error)" "ERR"
                }
            } catch {
                $window.FindName('lblGraphStatus').Text       = "Auth error: $($_.Exception.Message)"
                $window.FindName('lblGraphStatus').Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#C1554A')
                & $script:WriteLog "Auth error: $($_.Exception.Message)" "ERR"
            }
            $script:AuthPs = $null; $script:AuthHandle = $null
        }
    })
    $script:AuthTimer = $t
    $t.Start()
})

$window.FindName('btnLoadElevationReport').Add_Click({
    & $script:WriteLog "Fetching EPM elevation events from Microsoft Graph..."
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        # Silently refresh the access token if it has expired
        if ($script:GraphRefresh -and (Get-Date) -ge $script:GraphExpiry) {
            & $script:WriteLog "Access token expired — refreshing silently..." "INFO"
            $body = "client_id=$([System.Uri]::EscapeDataString($script:GraphClient))" +
                    "&refresh_token=$([System.Uri]::EscapeDataString($script:GraphRefresh))" +
                    "&grant_type=refresh_token" +
                    "&scope=$([System.Uri]::EscapeDataString($script:GraphScope))"
            $tok  = Invoke-RestMethod -Method POST -ErrorAction Stop `
                        -ContentType 'application/x-www-form-urlencoded' `
                        -Uri "https://login.microsoftonline.com/$($script:GraphTenant)/oauth2/v2.0/token" `
                        -Body $body
            $script:GraphToken   = $tok.access_token
            $script:GraphRefresh = $tok.refresh_token
            $script:GraphExpiry  = (Get-Date).AddSeconds($tok.expires_in - 60)
            & $script:WriteLog "Token refreshed. Valid until $($script:GraphExpiry.ToString('HH:mm:ss'))." "OK"
        }

        $headers  = @{ Authorization = "Bearer $($script:GraphToken)" }
        $allItems = [System.Collections.Generic.List[object]]::new()
        $uri      = 'https://graph.microsoft.com/beta/deviceManagement/privilegeManagementElevations'
        do {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -ErrorAction Stop
            if ($response.value) { foreach ($item in $response.value) { $allItems.Add($item) } }
            $uri = $response.'@odata.nextLink'
        } while ($uri)

        if ($allItems.Count -eq 0) {
            & $script:WriteLog "No elevation events returned." "WARN"
            $window.FindName('ResultGrid').ItemsSource = $null
            $window.FindName('RawOutput').Text         = ''
            $window.Cursor = [System.Windows.Input.Cursors]::Arrow
            return
        }

        $results = $allItems | ForEach-Object {
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
            }
        }

        & $script:WriteLog "Loaded $($results.Count) elevation event(s) — opening report window." "OK"

        # Serialize for the new STA runspace
        $json  = $results | ConvertTo-Json -Depth 5
        $count = $results.Count

        $gridScript = {
            param([string]$Json, [int]$Count)
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

            $w.FindName('btnClose').Add_Click({ $w.Close() })

            [void]$w.ShowDialog()
        }

        $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.ThreadOptions  = 'ReuseThread'
        $rs.Open()
        $ps2 = [System.Management.Automation.PowerShell]::Create()
        $ps2.Runspace = $rs
        [void]$ps2.AddScript($gridScript).AddParameters(@{ Json = $json; Count = $count })
        [void]$ps2.BeginInvoke()

    } catch {
        & $script:WriteLog "Error fetching elevation events: $($_.Exception.Message)" "ERR"
    }
    $window.Cursor = [System.Windows.Input.Cursors]::Arrow
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
